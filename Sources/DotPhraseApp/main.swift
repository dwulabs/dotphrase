import AppKit
import Carbon
import Foundation
import DotPhraseCore


final class EventTap {
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var buffer: String = ""
    private var inQuery: Bool = false
    private var query: String = ""

    private let store: PhraseStore

    var onMatches: ((String, [Phrase]) -> Void)?
    var onNavigate: ((Int) -> Void)?
    var onConfirm: (() -> Void)?
    var onCancel: (() -> Void)?

    init(store: PhraseStore) {
        self.store = store
    }

    func start() {
        let mask = (1 << CGEventType.keyDown.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard type == .keyDown else { return Unmanaged.passUnretained(event) }

            let mySelf = Unmanaged<EventTap>.fromOpaque(refcon!).takeUnretainedValue()
            mySelf.handle(event: event)

            return Unmanaged.passUnretained(event)
        }

        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: refcon
        )

        guard let tap else {
            NSLog("EventTap: failed to create (permissions likely missing)")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        NSLog("EventTap: started")
    }

    private func handle(event: CGEvent) {
        guard let s = keyString(event) else { return }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if inQuery {
            if keyCode == 126 { onNavigate?(-1); return } // up
            if keyCode == 125 { onNavigate?(+1); return } // down
        }

        // basic controls
        if s == "\u{1b}" { // Esc
            inQuery = false
            query = ""
            onCancel?()
            return
        }

        if s == "\r" { // Enter
            if inQuery {
                onConfirm?()
            }
            inQuery = false
            query = ""
            return
        }

        if s == "\u{08}" { // backspace
            if inQuery && !query.isEmpty {
                query.removeLast()
                if query.isEmpty { inQuery = false }
                showMatches()
            }
            return
        }

        // only track printable ascii letters/dot for MVP
        if s == "." {
            inQuery = true
            query = ""
            return
        }

        if inQuery {
            // require at least 1 letter to show dropdown
            if s.range(of: "^[A-Za-z]$", options: .regularExpression) != nil {
                query.append(s)
                showMatches()
            } else {
                // stop if non-letter
                inQuery = false
                query = ""
            }
        }
    }

    private func showMatches() {
        guard query.count >= 1 else {
            onMatches?(query, [])
            return
        }
        let matches = store.search(query, limit: 8)
        onMatches?(query, matches)
    }

    private func keyString(_ event: CGEvent) -> String? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // ignore command/option/control combos
        if flags.contains(.maskCommand) || flags.contains(.maskAlternate) || flags.contains(.maskControl) {
            return nil
        }

        // translate keycode -> unicode
        guard let source = TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue() as? TISInputSource,
              let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }

        let data = unsafeBitCast(layoutData, to: CFData.self)
        let ptr = CFDataGetBytePtr(data)
        let keyboardLayout = unsafeBitCast(ptr, to: UnsafePointer<UCKeyboardLayout>.self)

        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var realLength: Int = 0

        let modifiers: UInt32 = 0
        let keyAction: UInt16 = UInt16(kUCKeyActionDown)
        let keyboardType: UInt32 = UInt32(LMGetKbdType())

        let status = UCKeyTranslate(
            keyboardLayout,
            UInt16(keyCode),
            keyAction,
            modifiers,
            keyboardType,
            UInt32(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            chars.count,
            &realLength,
            &chars
        )

        guard status == noErr, realLength > 0 else { return nil }

        let str = String(utf16CodeUnits: chars, count: realLength)

        // Normalize common control keys
        if str == "\u{7f}" { return "\u{08}" }
        return str
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var eventTap: EventTap?
    private let popup = PopupController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.title = "."
            button.toolTip = "dotphrase"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu

        // Load sample phrases for now
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let phrasesURL = cwd.appendingPathComponent("resources").appendingPathComponent("phrases.sample.json")

        do {
            let store = try PhraseStore.loadJSON(from: phrasesURL)
            let tap = EventTap(store: store)
            tap.onMatches = { [weak self] query, matches in
                guard let self else { return }
                if matches.isEmpty {
                    Task { @MainActor in self.popup.hide() }
                    return
                }
                // TEMP: anchor near top-left; caret anchoring later
                let pt = NSPoint(x: 40, y: NSScreen.main?.frame.height ?? 600 - 120)
                Task { @MainActor in
                    self.popup.show(at: pt, matches: matches) { phrase in
                        // insertion later; for now just log selection
                        NSLog("selected .%s", phrase.trigger)
                    }
                }
            }
            tap.onNavigate = { [weak self] delta in
                guard let self else { return }
                Task { @MainActor in self.popup.moveSelection(delta: delta) }
            }
            tap.onConfirm = { [weak self] in
                guard let self else { return }
                Task { @MainActor in self.popup.confirmSelection() }
            }
            tap.onCancel = { [weak self] in
                guard let self else { return }
                Task { @MainActor in self.popup.hide() }
            }
            tap.start()
            self.eventTap = tap
        } catch {
            NSLog("Failed to load phrases: \(error)")
        }

        NSLog("dotphrase menubar started")
    }

    @MainActor
    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()