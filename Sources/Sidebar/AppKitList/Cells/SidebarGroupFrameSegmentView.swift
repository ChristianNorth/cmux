import AppKit

/// Which slice of a workspace group's rounded outline one sidebar row draws.
///
/// The AppKit sidebar renders a group as a header row followed by member
/// rows, so the group's border is drawn cooperatively: the header draws the
/// top edge and rounded top corners, members draw the side edges, and the
/// last member closes the bottom. A collapsed group's header draws the whole
/// rectangle alone. Rows overdraw the table's 2pt intercell gap below
/// themselves so the side edges join seamlessly.
enum SidebarGroupFrameSegment: Equatable {
    case top
    case middle
    case bottom
    case solo
}

/// Draws one row's slice of the group outline. Sits behind every other
/// subview of the cell and never participates in height measurement.
@MainActor
final class SidebarGroupFrameSegmentView: NSView {
    static let cornerRadius: CGFloat = 10
    static let lineWidth: CGFloat = 1.5
    /// The table's intercell gap, overdrawn below non-bottom segments.
    static let rowGapOverdraw: CGFloat = 2

    private var segment: SidebarGroupFrameSegment = .middle
    private var color: NSColor = .separatorColor
    private var fillColor: NSColor = .clear

    override var isFlipped: Bool { true }

    /// Workspace titles inside a colored group carry the group's tint:
    /// darkened slightly for light backgrounds, lightened for dark ones so
    /// both stay readable. Nil when the group has no color.
    static func workspaceTitleColor(tintHex: String?, colorSchemeIsDark: Bool) -> NSColor? {
        guard let base = tintHex.flatMap({ NSColor(hex: $0) }) else { return nil }
        return colorSchemeIsDark
            ? (base.blended(withFraction: 0.45, of: .white) ?? base)
            : (base.blended(withFraction: 0.15, of: .black) ?? base)
    }

    func configure(segment: SidebarGroupFrameSegment, tintHex: String?, colorSchemeIsDark: Bool) {
        self.segment = segment
        let base = tintHex.flatMap { NSColor(hex: $0) }
        let neutral = colorSchemeIsDark ? NSColor.white : NSColor.black
        self.color = (base ?? neutral).withAlphaComponent(base == nil ? 0.16 : 0.42)
        // A faint wash of the group color so the frame reads as a card, not a wire.
        self.fillColor = (base ?? neutral).withAlphaComponent(base == nil ? 0.03 : 0.045)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let radius = Self.cornerRadius
        let inset = Self.lineWidth / 2
        drawFill(radius: radius, inset: inset)
        let path = NSBezierPath()
        path.lineWidth = Self.lineWidth
        let left = bounds.minX + inset
        let right = bounds.maxX - inset
        let top = bounds.minY + inset
        // Non-bottom segments run their side edges past the row into the
        // intercell gap so consecutive rows' edges meet.
        let overdrawnBottom = bounds.maxY + Self.rowGapOverdraw
        let bottom = bounds.maxY - inset

        switch segment {
        case .top:
            path.move(to: NSPoint(x: left, y: overdrawnBottom))
            path.line(to: NSPoint(x: left, y: top + radius))
            path.appendArc(
                withCenter: NSPoint(x: left + radius, y: top + radius),
                radius: radius, startAngle: 180, endAngle: 270, clockwise: false
            )
            path.line(to: NSPoint(x: right - radius, y: top))
            path.appendArc(
                withCenter: NSPoint(x: right - radius, y: top + radius),
                radius: radius, startAngle: 270, endAngle: 360, clockwise: false
            )
            path.line(to: NSPoint(x: right, y: overdrawnBottom))
        case .middle:
            path.move(to: NSPoint(x: left, y: bounds.minY))
            path.line(to: NSPoint(x: left, y: overdrawnBottom))
            path.move(to: NSPoint(x: right, y: bounds.minY))
            path.line(to: NSPoint(x: right, y: overdrawnBottom))
        case .bottom:
            path.move(to: NSPoint(x: left, y: bounds.minY))
            path.line(to: NSPoint(x: left, y: bottom - radius))
            path.appendArc(
                withCenter: NSPoint(x: left + radius, y: bottom - radius),
                radius: radius, startAngle: 180, endAngle: 90, clockwise: true
            )
            path.line(to: NSPoint(x: right - radius, y: bottom))
            path.appendArc(
                withCenter: NSPoint(x: right - radius, y: bottom - radius),
                radius: radius, startAngle: 90, endAngle: 0, clockwise: true
            )
            path.line(to: NSPoint(x: right, y: bounds.minY))
        case .solo:
            path.appendRoundedRect(
                NSRect(x: left, y: top, width: right - left, height: bottom - top),
                xRadius: radius, yRadius: radius
            )
        }
        color.setStroke()
        path.stroke()
    }

    /// The interior wash for this row's slice: rounded only on the edges this
    /// segment owns, and overdrawn into the intercell gap below non-bottom
    /// segments so consecutive rows' fills join seamlessly.
    private func drawFill(radius: CGFloat, inset: CGFloat) {
        let left = bounds.minX + inset
        let right = bounds.maxX - inset
        let width = right - left
        let fill: NSBezierPath
        switch segment {
        case .top:
            let rect = NSRect(x: left, y: bounds.minY + inset, width: width, height: bounds.maxY + Self.rowGapOverdraw - (bounds.minY + inset))
            fill = NSBezierPath(roundedRect: rect, corners: [.topLeft, .topRight], radius: radius)
        case .middle:
            fill = NSBezierPath(rect: NSRect(x: left, y: bounds.minY, width: width, height: bounds.height + Self.rowGapOverdraw))
        case .bottom:
            let rect = NSRect(x: left, y: bounds.minY, width: width, height: bounds.maxY - inset - bounds.minY)
            fill = NSBezierPath(roundedRect: rect, corners: [.bottomLeft, .bottomRight], radius: radius)
        case .solo:
            fill = NSBezierPath(roundedRect: NSRect(x: left, y: bounds.minY + inset, width: width, height: bounds.height - inset * 2), xRadius: radius, yRadius: radius)
        }
        fillColor.setFill()
        fill.fill()
    }
}

private extension NSBezierPath {
    struct RoundedCorners: OptionSet {
        let rawValue: Int
        static let topLeft = RoundedCorners(rawValue: 1)
        static let topRight = RoundedCorners(rawValue: 2)
        static let bottomLeft = RoundedCorners(rawValue: 4)
        static let bottomRight = RoundedCorners(rawValue: 8)
    }

    /// A rect with only the given corners rounded (flipped coordinates:
    /// minY is the top edge).
    convenience init(roundedRect rect: NSRect, corners: RoundedCorners, radius: CGFloat) {
        self.init()
        let topLeft = NSPoint(x: rect.minX, y: rect.minY)
        let topRight = NSPoint(x: rect.maxX, y: rect.minY)
        let bottomRight = NSPoint(x: rect.maxX, y: rect.maxY)
        let bottomLeft = NSPoint(x: rect.minX, y: rect.maxY)
        move(to: NSPoint(x: topLeft.x + (corners.contains(.topLeft) ? radius : 0), y: topLeft.y))
        line(to: NSPoint(x: topRight.x - (corners.contains(.topRight) ? radius : 0), y: topRight.y))
        if corners.contains(.topRight) {
            appendArc(withCenter: NSPoint(x: topRight.x - radius, y: topRight.y + radius), radius: radius, startAngle: 270, endAngle: 360, clockwise: false)
        }
        line(to: NSPoint(x: bottomRight.x, y: bottomRight.y - (corners.contains(.bottomRight) ? radius : 0)))
        if corners.contains(.bottomRight) {
            appendArc(withCenter: NSPoint(x: bottomRight.x - radius, y: bottomRight.y - radius), radius: radius, startAngle: 0, endAngle: 90, clockwise: false)
        }
        line(to: NSPoint(x: bottomLeft.x + (corners.contains(.bottomLeft) ? radius : 0), y: bottomLeft.y))
        if corners.contains(.bottomLeft) {
            appendArc(withCenter: NSPoint(x: bottomLeft.x + radius, y: bottomLeft.y - radius), radius: radius, startAngle: 90, endAngle: 180, clockwise: false)
        }
        line(to: NSPoint(x: topLeft.x, y: topLeft.y + (corners.contains(.topLeft) ? radius : 0)))
        if corners.contains(.topLeft) {
            appendArc(withCenter: NSPoint(x: topLeft.x + radius, y: topLeft.y + radius), radius: radius, startAngle: 180, endAngle: 270, clockwise: false)
        }
        close()
    }
}

extension SidebarGroupFrameSegment {
    /// Computes each render item's outline slice: nil for ungrouped rows, and
    /// for grouped rows the slice determined by what follows in display order
    /// (a header followed by members opens the frame; the last member closes
    /// it; a collapsed or empty group's header draws the whole rectangle).
    static func segments(
        forRenderItems items: [SidebarWorkspaceRenderItem],
        groupIdByWorkspaceId: [UUID: UUID?],
        collapsedGroupIds: Set<UUID>
    ) -> [SidebarGroupFrameSegment?] {
        func groupId(of item: SidebarWorkspaceRenderItem) -> UUID? {
            switch item {
            case .groupHeader(let groupId, _):
                return groupId
            case .workspace(let workspaceId):
                return groupIdByWorkspaceId[workspaceId] ?? nil
            }
        }
        return items.indices.map { index in
            let item = items[index]
            let next = index + 1 < items.count ? items[index + 1] : nil
            switch item {
            case .groupHeader(let gid, _):
                if collapsedGroupIds.contains(gid) { return .solo }
                let nextIsMember = next.map { nextItem in
                    if case .workspace = nextItem { return groupId(of: nextItem) == gid }
                    return false
                } ?? false
                return nextIsMember ? .top : .solo
            case .workspace:
                guard let gid = groupId(of: item) else { return nil }
                let nextIsSameGroup = next.map { groupId(of: $0) == gid } ?? false
                return nextIsSameGroup ? .middle : .bottom
            }
        }
    }
}
