import AppKit
import os.log

private let searchLog = Logger(subsystem: "com.nkannan.launcher", category: "search")

// Spotlight-style app search. A non-activating panel, built on first use and then only shown/hidden.
// Return opens the selection, ↑↓ / ⌃N⌃P / Tab move, ⌘1-9 open by position, ⌘Return reveals in Finder,
// Esc or clicking elsewhere closes. Empty query lists your most-used apps.
final class SearchPanel: NSObject, NSTextFieldDelegate, NSWindowDelegate {
    static let shared = SearchPanel()
    static let width: CGFloat = 640, fieldH: CGFloat = 56, rowH: CGFloat = 40, maxRows = 8

    private let index = AppIndex()
    private let frecency = Frecency(url: Frecency.defaultURL)
    private var panel: KeyPanel?
    private let field = NSTextField()
    private var rows: [RowView] = []
    private var results: [AppEntry] = []
    private var icons: [String: NSImage] = [:]
    private var selected = 0
    private var top: CGFloat = 0

    func toggle() { panel?.isVisible == true ? hide() : show() }

    func warm() {
        index.onChange = { [weak self] in if self?.panel?.isVisible == true { self?.update() } }
        index.start()
    }

    func show() {
        warm()
        let p = panel ?? build()
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main ?? NSScreen.screens[0]
        let vf = screen.visibleFrame
        top = vf.maxY - vf.height * 0.18
        p.setFrameOrigin(NSPoint(x: vf.midX - SearchPanel.width / 2, y: top - SearchPanel.fieldH))
        field.stringValue = ""
        update()
        p.makeKeyAndOrderFront(nil)
        p.makeFirstResponder(field)
    }

    func hide() {
        guard panel?.isVisible == true else { return }
        panel?.orderOut(nil)
        NSApp.deactivate()  // hand keyboard focus back to the app underneath
    }

    // MARK: results

    private func update() {
        results = Ranking.rank(index.apps, field.stringValue, frecency, limit: SearchPanel.maxRows)
        selected = 0
        layout()
    }

    private func move(_ d: Int) {
        guard !results.isEmpty else { return }
        selected = (selected + d + results.count) % results.count
        layout()
    }

    private func open(_ i: Int, reveal: Bool = false) {
        guard results.indices.contains(i) else { return }
        let a = results[i]
        frecency.record(a.id, query: field.stringValue)
        panel?.orderOut(nil)
        if reveal { return NSWorkspace.shared.activateFileViewerSelecting([a.url]) }
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.activates = true
        NSWorkspace.shared.openApplication(at: a.url, configuration: cfg) { _, error in
            if let error { searchLog.error("open \(a.id, privacy: .public): \(error.localizedDescription, privacy: .public)") }
        }
    }

    private func icon(_ a: AppEntry) -> NSImage {
        if let i = icons[a.id] { return i }
        let i = NSWorkspace.shared.icon(forFile: a.url.path)
        icons[a.id] = i
        return i
    }

    // MARK: layout (fixed top edge; the panel grows downward with the result count)

    private func layout() {
        guard let p = panel else { return }
        let w = SearchPanel.width, n = CGFloat(results.count)
        let h = SearchPanel.fieldH + (results.isEmpty ? 0 : n * SearchPanel.rowH + 8)
        p.setFrame(NSRect(x: p.frame.minX, y: top - h, width: w, height: h), display: false)
        field.frame = NSRect(x: 20, y: h - SearchPanel.fieldH + 12, width: w - 40, height: 32)
        for (i, r) in rows.enumerated() {
            r.isHidden = i >= results.count
            guard !r.isHidden else { continue }
            r.frame = NSRect(x: 8, y: h - SearchPanel.fieldH - CGFloat(i + 1) * SearchPanel.rowH, width: w - 16, height: SearchPanel.rowH)
            r.set(results[i].name, icon: icon(results[i]), hint: i < 9 ? "⌘\(i + 1)" : "", selected: i == selected)
        }
        p.contentView?.needsDisplay = true
    }

    private func build() -> KeyPanel {
        let p = KeyPanel(contentRect: NSRect(x: 0, y: 0, width: SearchPanel.width, height: SearchPanel.fieldH),
                         styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.level = .popUpMenu
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        p.delegate = self
        p.onKey = { [weak self] e in self?.keyEquivalent(e) ?? false }
        let bg = NSVisualEffectView()
        bg.material = .popover
        bg.blendingMode = .behindWindow
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 14
        bg.layer?.masksToBounds = true
        p.contentView = bg
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 22)
        field.placeholderString = "Open app"
        field.cell?.usesSingleLineMode = true
        field.delegate = self
        bg.addSubview(field)
        rows = (0..<SearchPanel.maxRows).map { i in
            let r = RowView()
            r.onClick = { [weak self] in self?.open(i) }
            bg.addSubview(r)
            return r
        }
        panel = p
        return p
    }

    // MARK: keys

    func controlTextDidChange(_ n: Notification) { update() }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy sel: Selector) -> Bool {
        switch sel {
        case #selector(NSResponder.moveDown(_:)), #selector(NSResponder.insertTab(_:)): move(1)
        case #selector(NSResponder.moveUp(_:)), #selector(NSResponder.insertBacktab(_:)): move(-1)
        case #selector(NSResponder.insertNewline(_:)): open(selected)
        case #selector(NSResponder.cancelOperation(_:)): hide()
        default: return false
        }
        return true
    }

    private func keyEquivalent(_ e: NSEvent) -> Bool {
        guard e.modifierFlags.contains(.command), let c = e.charactersIgnoringModifiers else { return false }
        if c == "\r" { open(selected, reveal: true); return true }
        if let n = Int(c), (1...9).contains(n) { open(n - 1); return true }
        return false
    }

    func windowDidResignKey(_ n: Notification) { hide() }
}

final class KeyPanel: NSPanel {
    var onKey: ((NSEvent) -> Bool)?
    override var canBecomeKey: Bool { true }
    override func performKeyEquivalent(with e: NSEvent) -> Bool { onKey?(e) == true || super.performKeyEquivalent(with: e) }
}

private final class RowView: NSView {
    var onClick: (() -> Void)?
    private let image = NSImageView()
    private let name = NSTextField(labelWithString: "")
    private let hint = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 8
        name.font = .systemFont(ofSize: 15)
        name.lineBreakMode = .byTruncatingTail
        hint.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        hint.textColor = .tertiaryLabelColor
        hint.alignment = .right
        [image, name, hint].forEach(addSubview)
    }

    required init?(coder: NSCoder) { nil }

    func set(_ title: String, icon: NSImage, hint h: String, selected: Bool) {
        image.image = icon
        name.stringValue = title
        hint.stringValue = h
        layer?.backgroundColor = selected ? NSColor.controlAccentColor.withAlphaComponent(0.25).cgColor : nil
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let h = bounds.height, w = bounds.width
        image.frame = NSRect(x: 10, y: (h - 28) / 2, width: 28, height: 28)
        name.frame = NSRect(x: 48, y: (h - 20) / 2, width: w - 110, height: 20)
        hint.frame = NSRect(x: w - 56, y: (h - 16) / 2, width: 44, height: 16)
    }

    override func mouseDown(with e: NSEvent) { onClick?() }
}
