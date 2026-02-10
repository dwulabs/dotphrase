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

        // basic controls
        if s == "\u{1b}" { // Esc
            inQuery = false
            query = ""
            return
        }

        if s == "\r" { // Enter
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
        guard query.count >= 1 else { return }
        let matches = store.search(query, limit: 5)
        if matches.isEmpty {
            NSLog("dotphrase query=\(query) (no matches)")
        } else {
            let list = matches.map { "." + $0.trigger }.joined(separator: ", ")
            NSLog("dotphrase query=\(query) matches: \(list)")
        }
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

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var eventTap: EventTap?

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
