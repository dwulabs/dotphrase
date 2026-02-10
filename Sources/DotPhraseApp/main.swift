import AppKit
import Carbon
import Foundation
@preconcurrency import ApplicationServices
import DotPhraseCore


final class EventTap {
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    var onStartFailed: (() -> Void)?

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

    @discardableResult
    func start() -> Bool {
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
            Log.write("EventTap failed to create")
            onStartFailed?()
            return false
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        NSLog("EventTap: started")
        Log.write("EventTap started")
        return true
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
            Log.write("dot trigger")
            return
        }

        if inQuery {
            // require at least 1 letter to show dropdown
            if s.range(of: "^[A-Za-z]$", options: .regularExpression) != nil {
                query.append(s)
                Log.write("query_update=\(query)")
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
        let source = TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue()
        guard let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
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
    private var statusMenu: NSMenu!
    private var axMenuItem: NSMenuItem!
    private var tapMenuItem: NSMenuItem!
    private var monitorMenuItem: NSMenuItem!

    private var eventTap: EventTap?
    private var globalMonitor: GlobalKeyMonitor?
    private let popup = PopupController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prompt for Accessibility trust if needed (required for event tap + later insertion)
        let axOpts: CFDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let axTrusted = AXIsProcessTrustedWithOptions(axOpts)
        Log.write("AX trusted=\(axTrusted)")
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.title = "."
            button.toolTip = "dotphrase"
            if !axTrusted {
                button.title = "!."
                button.toolTip = "dotphrase (needs Accessibility / Input Monitoring permission)"
            }
        }

        statusMenu = NSMenu()
        let axStatus = axTrusted ? "OK" : "NOT GRANTED"
        axMenuItem = NSMenuItem(title: "Accessibility: \(axStatus)", action: nil, keyEquivalent: "")
        tapMenuItem = NSMenuItem(title: "Event tap: starting...", action: nil, keyEquivalent: "")
        monitorMenuItem = NSMenuItem(title: "Input monitoring: starting...", action: nil, keyEquivalent: "")
        statusMenu.addItem(axMenuItem)
        statusMenu.addItem(tapMenuItem)
        statusMenu.addItem(monitorMenuItem)
        statusMenu.addItem(NSMenuItem.separator())

        let openAX = NSMenuItem(title: "Open Accessibility Settings", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        openAX.target = self
        statusMenu.addItem(openAX)

        let openIM = NSMenuItem(title: "Open Input Monitoring Settings", action: #selector(openInputMonitoringSettings), keyEquivalent: "")
        openIM.target = self
        statusMenu.addItem(openIM)

        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(NSMenuItem(title: "Log: /tmp/dotphrase.log", action: nil, keyEquivalent: ""))
        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = statusMenu

        // Load sample phrases for now
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let phrasesURL = cwd.appendingPathComponent("resources").appendingPathComponent("phrases.sample.json")

        do {
            let store = try PhraseStore.loadJSON(from: phrasesURL)
            let tap = EventTap(store: store)
            let gmon = GlobalKeyMonitor(store: store)
            tap.onStartFailed = { [weak self] in
                guard let self else { return }
                self.tapMenuItem.title = "Event tap: FAILED"
                if let button = self.statusItem.button {
                    button.title = "!."
                    button.toolTip = "dotphrase (needs Accessibility / Input Monitoring permission)"
                }
                Log.write("EventTap start failed (likely missing Accessibility)")
                Task { @MainActor in self.popup.hide() }
            }
            tap.onMatches = { [weak self] query, matches in
                guard let self else { return }
                if let button = self.statusItem.button {
                    button.title = "." + query.lowercased()
                }
                Log.write("query=\(query) matches=\(matches.count)")
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
            // wire fallback global key monitor (requires Input Monitoring permission)
            gmon.onMatches = tap.onMatches
            gmon.onNavigate = tap.onNavigate
            gmon.onConfirm = tap.onConfirm
            gmon.onCancel = tap.onCancel
            let gmonOK = gmon.start()
            self.monitorMenuItem.title = gmonOK ? "Input monitoring: OK" : "Input monitoring: FAILED"
            self.globalMonitor = gmon

            let tapOK = tap.start()
            self.tapMenuItem.title = tapOK ? "Event tap: OK" : "Event tap: FAILED"
            self.eventTap = tapOK ? tap : nil
        } catch {
            NSLog("Failed to load phrases: \(error)")
        }

        NSLog("dotphrase menubar started")
    }

    @MainActor
    @objc private func openAccessibilitySettings() {
        // Privacy & Security → Accessibility
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @MainActor
    @objc private func openInputMonitoringSettings() {
        // Privacy & Security → Input Monitoring
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
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
