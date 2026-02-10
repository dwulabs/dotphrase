import AppKit
import DotPhraseCore

@MainActor
final class PopupController: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    private let panel: NSPanel
    private let scrollView: NSScrollView
    private let tableView: NSTableView

    private var matches: [Phrase] = []
    private var onSelect: ((Phrase) -> Void)?

    override init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 220),
            styleMask: [.nonactivatingPanel, .titled],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.title = "dotphrase"

        scrollView = NSScrollView(frame: panel.contentView?.bounds ?? .zero)
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        tableView = NSTableView(frame: scrollView.bounds)
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("phrase"))
        col.title = ""
        col.width = 340
        tableView.addTableColumn(col)
        tableView.headerView = nil
        tableView.rowHeight = 26
        tableView.intercellSpacing = NSSize(width: 0, height: 4)

        super.init()

        tableView.dataSource = self
        tableView.delegate = self

        scrollView.documentView = tableView
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(scrollView)
        panel.contentView = content

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            scrollView.topAnchor.constraint(equalTo: content.topAnchor, constant: 10),
            scrollView.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -10),
        ])
    }

    func show(at point: NSPoint, matches: [Phrase], onSelect: @escaping (Phrase) -> Void) {
        self.matches = matches
        self.onSelect = onSelect
        tableView.reloadData()

        if tableView.numberOfRows > 0 {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }

        if !panel.isVisible {
            panel.setFrameOrigin(point)
        }
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
        matches = []
        onSelect = nil
    }

    func moveSelection(delta: Int) {
        let n = tableView.numberOfRows
        guard n > 0 else { return }

        let current = max(tableView.selectedRow, 0)
        let next = min(max(current + delta, 0), n - 1)
        tableView.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
        tableView.scrollRowToVisible(next)
    }

    func confirmSelection() {
        let idx = tableView.selectedRow
        guard idx >= 0 && idx < matches.count else { return }
        onSelect?(matches[idx])
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        matches.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("cell")
        let phrase = matches[row]

        let view: NSTableCellView
        if let existing = tableView.makeView(withIdentifier: id, owner: self) as? NSTableCellView {
            view = existing
        } else {
            view = NSTableCellView()
            view.identifier = id
            let label = NSTextField(labelWithString: "")
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)
            label.lineBreakMode = .byTruncatingTail
            view.addSubview(label)
            view.textField = label

            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
                label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
                label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            ])
        }

        let desc = phrase.description ?? ""
        view.textField?.stringValue = ".\(phrase.trigger)  \(desc)"
        return view
    }
}
