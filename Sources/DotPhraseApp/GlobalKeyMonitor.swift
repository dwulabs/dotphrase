import AppKit
import Foundation
import DotPhraseCore

/// Fallback capture mechanism using NSEvent global monitor.
///
/// Pros: simpler, often works when event taps are finicky.
/// Cons: requires Input Monitoring permission and cannot intercept/modify events.
final class GlobalKeyMonitor {
    private var monitor: Any?

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
        guard monitor == nil else { return }

        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.handle(event)
        }

        Log.write("GlobalKeyMonitor started")
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        Log.write("GlobalKeyMonitor stopped")
    }

    private func handle(_ event: NSEvent) {
        // ignore command/option/control combos
        if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.option) || event.modifierFlags.contains(.control) {
            return
        }

        let keyCode = Int(event.keyCode)

        if inQuery {
            if keyCode == 126 { onNavigate?(-1); return } // up
            if keyCode == 125 { onNavigate?(+1); return } // down
        }

        // Esc
        if keyCode == 53 {
            inQuery = false
            query = ""
            onCancel?()
            return
        }

        // Enter
        if keyCode == 36 {
            if inQuery { onConfirm?() }
            inQuery = false
            query = ""
            return
        }

        // Backspace
        if keyCode == 51 {
            if inQuery && !query.isEmpty {
                query.removeLast()
                if query.isEmpty { inQuery = false }
                showMatches()
            }
            return
        }

        let s = (event.charactersIgnoringModifiers ?? "")

        if s == "." {
            inQuery = true
            query = ""
            Log.write("dot trigger (global)")
            return
        }

        if inQuery {
            if s.range(of: "^[A-Za-z]$", options: .regularExpression) != nil {
                query.append(s)
                Log.write("query_update(global)=\(query)")
                showMatches()
            } else {
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
}
