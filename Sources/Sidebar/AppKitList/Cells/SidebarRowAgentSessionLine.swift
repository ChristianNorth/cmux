import AppKit

/// One agent session line inside a sidebar workspace row.
///
/// Every line leads with a fixed gutter carrying the session's ordinal
/// (1..N within the workspace); an attention ball — red for needs-input,
/// blue for an unread finished session — takes the ordinal's place, so the
/// title column never moves. State lives in the title color (plain = idle,
/// blue = running). The fixed-width age column carries an orange recency
/// marker for the three sessions the user most recently typed into. Owns its
/// click (swallowed from the table row action) and focuses the session's pane.
@MainActor
final class SidebarRowAgentSessionLine: NSControl {
    var onClick: (() -> Void)?

    static let ballSide: CGFloat = 7
    private static let gutterGap: CGFloat = 4
    private static let ageGap: CGFloat = 6
    private static let promptSpacing: CGFloat = 1

    private let ballView = NSView()
    private let numberView = SidebarRowTextView(lines: 1)
    private let titleView = SidebarRowTextView(lines: 2)
    private let ageView = SidebarRowTextView(lines: 1)
    private let promptView = SidebarRowTextView(lines: 1)
    private var ageColumnWidth: CGFloat = 0
    private var gutterWidth: CGFloat = 0
    private var showsBall = false
    private var titleFont: NSFont = .systemFont(ofSize: 10.5)

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        ballView.wantsLayer = true
        ballView.layer?.cornerRadius = Self.ballSide / 2
        ballView.isHidden = true
        addSubview(ballView)
        numberView.lineBreakMode = .byClipping
        addSubview(numberView)
        addSubview(titleView)
        ageView.alignment = .right
        ageView.lineBreakMode = .byClipping
        addSubview(ageView)
        promptView.isHidden = true
        addSubview(promptView)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Running titles are blue; everything else keeps the row's normal text color.
    static func runningTitleColor(isActive: Bool, colorSchemeIsDark: Bool) -> NSColor {
        if isActive { return NSColor(hex: "#9cc3ff") ?? .systemBlue }
        return (colorSchemeIsDark ? NSColor(hex: "#6ca5f0") : NSColor(hex: "#2f6fd0")) ?? .systemBlue
    }

    /// Needs-input ball: red. Unread-finished ball: blue.
    static func ballColor(needsInput: Bool, isActive: Bool, colorSchemeIsDark: Bool) -> NSColor {
        if needsInput {
            return (isActive ? NSColor(hex: "#ff6b62") : NSColor(hex: "#d64540")) ?? .systemRed
        }
        return runningTitleColor(isActive: isActive, colorSchemeIsDark: colorSchemeIsDark)
    }

    /// Recency markers (◀ / ‹) draw in a distinct orange.
    static func markerColor(isActive: Bool, colorSchemeIsDark: Bool) -> NSColor {
        if isActive { return NSColor(hex: "#f5a15c") ?? .systemOrange }
        return (colorSchemeIsDark ? NSColor(hex: "#e8853f") : NSColor(hex: "#da702c")) ?? .systemOrange
    }

    /// The age column is sized for the widest template so a ticking age or an
    /// appearing marker never moves the title or changes the line's height.
    static func ageColumnWidth(font: NSFont) -> CGFloat {
        // Measure through a text field cell so its horizontal padding is included;
        // a bare attributed-string width leaves the widest template truncated.
        let widest = SidebarAgentSessionAgeFormatter.columnTemplates
            .map { template -> CGFloat in
                let cell = NSTextFieldCell(textCell: template)
                cell.font = font
                cell.lineBreakMode = .byClipping
                return cell.cellSize.width
            }
            .max() ?? 0
        return ceil(widest) + 2
    }

    /// The leading gutter is sized for the workspace's widest ordinal (and
    /// never narrower than the ball), so titles align across the workspace's
    /// lines and never move when a ball replaces a number — while a typical
    /// single-digit workspace stays tight.
    static func gutterWidth(numberFont: NSFont, maxOrdinal: Int) -> CGFloat {
        let widestDigits = String(repeating: "8", count: max(1, String(maxOrdinal).count))
        let cell = NSTextFieldCell(textCell: widestDigits)
        cell.font = numberFont
        cell.lineBreakMode = .byClipping
        return max(ceil(cell.cellSize.width), ballSide) + gutterGap
    }

    func configure(
        _ display: SidebarRowAgentSessionDisplay,
        model: SidebarWorkspaceRowModel,
        palette: SidebarRowPalette,
        maxOrdinal: Int
    ) {
        titleFont = .systemFont(ofSize: model.scaled(10.5), weight: .medium)
        let ageFont = NSFont.monospacedDigitSystemFont(ofSize: model.scaled(9.5), weight: .regular)
        showsBall = display.state == .needsInput || display.showsUnreadBall
        ballView.isHidden = !showsBall
        if showsBall {
            ballView.layer?.backgroundColor = Self.ballColor(
                needsInput: display.state == .needsInput,
                isActive: model.isActive,
                colorSchemeIsDark: model.colorSchemeIsDark
            ).cgColor
        }
        numberView.isHidden = showsBall
        numberView.stringValue = String(display.ordinal)
        numberView.font = ageFont
        numberView.textColor = palette.secondary(0.62, inactiveOpacity: 0.7)
        numberView.alignment = .center
        gutterWidth = Self.gutterWidth(numberFont: ageFont, maxOrdinal: maxOrdinal)
        titleView.stringValue = display.title
        titleView.font = titleFont
        titleView.textColor = display.state == .running
            ? Self.runningTitleColor(isActive: model.isActive, colorSchemeIsDark: model.colorSchemeIsDark)
            : palette.secondary(0.92, inactiveOpacity: 0.95)
        let age = NSMutableAttributedString(
            string: display.ageText,
            attributes: [
                .font: ageFont,
                .foregroundColor: palette.secondary(0.62, inactiveOpacity: 0.7),
            ]
        )
        if let rank = display.recencyRank {
            age.append(NSAttributedString(
                string: " " + SidebarRowAgentSessionDisplay.markerGlyph(forRecencyRank: rank),
                attributes: [
                    .font: NSFont.systemFont(ofSize: model.scaled(9.5), weight: .heavy),
                    .foregroundColor: Self.markerColor(isActive: model.isActive, colorSchemeIsDark: model.colorSchemeIsDark),
                ]
            ))
        }
        ageView.attributedStringValue = age
        ageColumnWidth = Self.ageColumnWidth(font: ageFont)
        promptView.isHidden = display.promptLine == nil
        if let promptLine = display.promptLine {
            promptView.stringValue = promptLine
            promptView.font = .systemFont(ofSize: model.scaled(9.5))
            promptView.textColor = palette.secondary(0.55, inactiveOpacity: 0.6)
        }
        toolTip = display.toolTip
        setAccessibilityLabel(display.accessibilityLabel)
        setAccessibilityIdentifier("sidebarAgentSession.\(display.panelId.uuidString)")
        needsLayout = true
    }

    /// Test seam: whether the leading attention ball (red needs-input or blue
    /// unread) is visible.
    var hasVisibleBall: Bool { !ballView.isHidden }

    /// Test seam: the ordinal shown in the leading gutter, nil while a ball
    /// takes its place.
    var numberDisplayText: String? { numberView.isHidden ? nil : numberView.stringValue }

    /// Test seam: the rendered age text including any recency marker.
    var ageDisplayText: String { ageView.attributedStringValue.string }

    func resetForReuse() {
        onClick = nil
        toolTip = nil
        titleView.stringValue = ""
        numberView.stringValue = ""
        numberView.isHidden = true
        ageView.stringValue = ""
        promptView.stringValue = ""
        promptView.isHidden = true
        ballView.isHidden = true
        showsBall = false
        alphaValue = 1
    }

    private var titleInset: CGFloat { gutterWidth }

    private var titleWidth: CGFloat {
        max(10, bounds.width - titleInset - ageColumnWidth - Self.ageGap)
    }

    func measuredHeight(width: CGFloat) -> CGFloat {
        let titleWidth = max(10, width - titleInset - ageColumnWidth - Self.ageGap)
        var height = titleView.measuredHeight(width: titleWidth)
        if !promptView.isHidden {
            height += Self.promptSpacing + promptView.measuredHeight(width: max(10, width - titleInset))
        }
        return height
    }

    override func layout() {
        super.layout()
        let titleHeight = titleView.measuredHeight(width: titleWidth)
        let firstLineHeight = ceil(titleFont.ascender - titleFont.descender + titleFont.leading)
        let firstLineCenter = firstLineHeight / 2
        let gutterContentWidth = max(0, gutterWidth - Self.gutterGap)
        if showsBall {
            ballView.frame = NSRect(
                x: (gutterContentWidth - Self.ballSide) / 2, y: firstLineCenter - Self.ballSide / 2,
                width: Self.ballSide, height: Self.ballSide
            )
        }
        if !numberView.isHidden {
            let numberHeight = numberView.sidebarNaturalCellSize.height
            numberView.frame = NSRect(
                x: 0, y: firstLineCenter - numberHeight / 2,
                width: gutterContentWidth, height: numberHeight
            )
        }
        let titleX = titleInset
        titleView.frame = NSRect(x: titleX, y: 0, width: titleWidth, height: titleHeight)
        let ageHeight = ageView.sidebarNaturalCellSize.height
        ageView.frame = NSRect(
            x: bounds.width - ageColumnWidth, y: firstLineCenter - ageHeight / 2,
            width: ageColumnWidth, height: ageHeight
        )
        if !promptView.isHidden {
            let promptWidth = max(10, bounds.width - titleX)
            let promptHeight = promptView.measuredHeight(width: promptWidth)
            promptView.frame = NSRect(
                x: titleX, y: titleHeight + Self.promptSpacing,
                width: promptWidth, height: promptHeight
            )
        }
    }

    // Swallow the press so the table row action does not also fire, dim while
    // pressed like the checklist summary line, fire on release inside bounds.
    override func mouseDown(with event: NSEvent) {
        alphaValue = SidebarRowPressedDim.pressedAlpha
    }

    override func mouseUp(with event: NSEvent) {
        alphaValue = 1
        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point) else { return }
        onClick?()
    }

    override func accessibilityPerformPress() -> Bool {
        guard let onClick else { return false }
        onClick()
        return true
    }
}
