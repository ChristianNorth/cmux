import AppKit

/// The block of agent session lines under a workspace title. Lines are pooled
/// positionally (they hold no per-session state), and every input that
/// changes what they draw is part of the row model, so the height cache's
/// prototype cell measures exactly what the live cell shows.
@MainActor
final class SidebarRowAgentSessionsSection: NSView {
    var onFocusSession: ((UUID) -> Void)?

    static let lineSpacing: CGFloat = 3

    /// Left offset of every line so the gutter (ordinal or ball) starts at
    /// the workspace title's x, past any leading badge or glyph. Set by the
    /// host cell's layoutContent, which is the only place that knows the
    /// title's position.
    var titleIndent: CGFloat = 0 {
        didSet { if oldValue != titleIndent { needsLayout = true } }
    }

    private var lines: [SidebarRowAgentSessionLine] = []
    private var rows: [SidebarRowAgentSessionDisplay] = []

    private struct ConfigureKey: Equatable {
        let workspaceId: UUID
        let rows: [SidebarRowAgentSessionDisplay]
        let isActive: Bool
        let isMultiSelected: Bool
        let colorSchemeIsDark: Bool
        let settings: SidebarTabItemSettingsSnapshot
        let magnificationPercent: Int
    }

    private var lastConfigureKey: ConfigureKey?

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        rows: [SidebarRowAgentSessionDisplay],
        model: SidebarWorkspaceRowModel,
        palette: SidebarRowPalette
    ) {
        let key = ConfigureKey(
            workspaceId: model.workspaceId,
            rows: rows,
            isActive: model.isActive,
            isMultiSelected: model.isMultiSelected,
            colorSchemeIsDark: model.colorSchemeIsDark,
            settings: model.settings,
            magnificationPercent: model.globalFontMagnificationPercent
        )
        if key == lastConfigureKey { return }
        lastConfigureKey = key
        self.rows = rows
        isHidden = rows.isEmpty
        while lines.count < rows.count {
            let line = SidebarRowAgentSessionLine()
            addSubview(line)
            lines.append(line)
        }
        for (index, line) in lines.enumerated() {
            guard index < rows.count else {
                line.isHidden = true
                line.resetForReuse()
                continue
            }
            let row = rows[index]
            line.isHidden = false
            line.configure(row, model: model, palette: palette, maxOrdinal: rows.count)
            let panelId = row.panelId
            line.onClick = { [weak self] in self?.onFocusSession?(panelId) }
        }
        needsLayout = true
    }

    func resetForReuse() {
        lastConfigureKey = nil
        rows = []
        isHidden = true
        for line in lines {
            line.isHidden = true
            line.resetForReuse()
        }
    }

    /// Deterministic height for the given width; independent of window,
    /// focus, or hover so the prototype cell measures the live cell's height.
    func measuredHeight(width: CGFloat) -> CGFloat {
        guard !isHidden, !rows.isEmpty else { return 0 }
        let lineWidth = max(10, width - titleIndent)
        var height: CGFloat = 0
        for (index, line) in lines.enumerated() where index < rows.count {
            if index > 0 { height += Self.lineSpacing }
            height += line.measuredHeight(width: lineWidth)
        }
        return height
    }

    override func layout() {
        super.layout()
        let lineWidth = max(10, bounds.width - titleIndent)
        var y: CGFloat = 0
        for (index, line) in lines.enumerated() where index < rows.count {
            if index > 0 { y += Self.lineSpacing }
            let height = line.measuredHeight(width: lineWidth)
            line.frame = NSRect(x: titleIndent, y: y, width: lineWidth, height: height)
            y += height
        }
    }
}
