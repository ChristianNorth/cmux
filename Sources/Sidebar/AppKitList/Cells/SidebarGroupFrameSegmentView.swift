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

    override var isFlipped: Bool { true }

    func configure(segment: SidebarGroupFrameSegment, tintHex: String?, colorSchemeIsDark: Bool) {
        self.segment = segment
        let base = tintHex.flatMap { NSColor(hex: $0) }
        let neutral = colorSchemeIsDark ? NSColor.white : NSColor.black
        self.color = (base ?? neutral).withAlphaComponent(base == nil ? 0.16 : 0.42)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let radius = Self.cornerRadius
        let inset = Self.lineWidth / 2
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
