import AppKit
import SwiftUI
import Foundation
import Testing

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

/// The agent session lines inside the AppKit workspace row cell: rendering,
/// height accounting, click routing, state colors, balls, markers, and the
/// group outline slice.
@MainActor
struct SidebarAppKitRowCellAgentSessionsTests {
    private static func display(
        panelId: UUID = UUID(),
        title: String = "Fix the login bug",
        state: SidebarAgentSessionSnapshot.State = .running,
        ageText: String = "12m",
        recencyRank: Int? = nil,
        showsUnreadBall: Bool = false,
        promptLine: String? = nil,
        toolTip: String = "Fix the login bug"
    ) -> SidebarRowAgentSessionDisplay {
        SidebarRowAgentSessionDisplay(
            panelId: panelId,
            title: title,
            state: state,
            ageText: ageText,
            recencyRank: recencyRank,
            showsUnreadBall: showsUnreadBall,
            promptLine: promptLine,
            toolTip: toolTip,
            accessibilityLabel: "Claude: \(title)"
        )
    }

    private static func makeModel(
        rows: [SidebarRowAgentSessionDisplay],
        groupFrameSegment: SidebarGroupFrameSegment? = nil,
        groupTintHex: String? = nil
    ) -> SidebarWorkspaceRowModel {
        let settings = SidebarTabItemSettingsSnapshot(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        return SidebarWorkspaceRowModel(
            workspaceId: UUID(),
            index: 0,
            snapshot: SidebarWorkspaceSnapshotRefreshPolicyTests.snapshot(),
            settings: settings,
            isActive: false,
            isMultiSelected: false,
            hasUserCustomTitle: false,
            canCloseWorkspace: true,
            accessibilityWorkspaceCount: 1,
            unreadCount: 0,
            latestNotificationText: nil,
            showsAgentActivity: false,
            rowSpacing: 8,
            isBeingDragged: false,
            topDropIndicatorVisible: false,
            bottomDropIndicatorVisible: false,
            isGrouped: false,
            isFirstRow: true,
            shortcutHintText: nil,
            showsShortcutHints: false,
            colorSchemeIsDark: true,
            globalFontMagnificationPercent: 100,
            isChecklistExpanded: false,
            checklistAddFieldActivationToken: 0,
            isChecklistPopoverPresented: false,
            editingChecklistItemId: nil,
            todoControlsEnabled: false,
            isMetadataExpanded: false,
            isMarkdownExpanded: false,
            agentSessionRows: rows,
            groupFrameSegment: groupFrameSegment,
            groupTintHex: groupTintHex
        )
    }

    private static func makeActions(
        model: SidebarWorkspaceRowModel,
        focusAgentSurface: @escaping (UUID) -> Void = { _ in }
    ) -> SidebarAppKitRowActions {
        let commands = SidebarWorkspaceRowCommands(
            tab: Workspace(),
            tabManager: nil,
            notificationStore: nil,
            index: model.index,
            contextMenuWorkspaceIds: [model.workspaceId],
            remoteContextMenuWorkspaceIds: [],
            allRemoteContextMenuTargetsConnecting: false,
            allRemoteContextMenuTargetsDisconnected: false,
            contextMenuPinState: nil,
            workspaceGroupMenuSnapshot: WorkspaceGroupMenuSnapshot(items: []),
            colorScheme: .dark,
            refreshSnapshot: {},
            readSelectedTabIds: { [] },
            writeSelectedTabIds: { _ in },
            readLastSelectionIndex: { nil },
            writeLastSelectionIndex: { _ in },
            setSelectionToTabs: {},
            snapshotProvider: { nil }
        )
        return SidebarAppKitRowActions(
            commands: commands,
            onOpenStatusURL: { _ in },
            onOpenWorkspaceDescriptionURL: { _ in },
            onOpenPullRequest: { _ in },
            onOpenPort: { _ in },
            onToggleChecklistExpansion: {},
            onToggleMetadataExpansion: {},
            onToggleMarkdownExpansion: {},
            onConsumeChecklistAddFieldActivation: {},
            checklistSetItemState: { _, _ in },
            checklistRemoveItem: { _ in },
            checklistAddItem: { _ in },
            checklistEditItem: { _, _ in },
            checklistMoveItem: { _, _ in },
            checklistOpenPane: {},
            checklistAddAttachments: { _ in },
            checklistRemoveAttachment: { _, _ in },
            checklistOpenAttachments: { _, _ in },
            onChecklistPopoverPresentedChange: { _ in },
            onBeginChecklistItemEdit: { _ in },
            onEndChecklistItemEdit: { _ in },
            applyTodoStatus: { _ in },
            hideTodoStatus: {},
            commitRename: { _ in },
            focusAgentSurface: focusAgentSurface
        )
    }

    private static func configuredCell(
        model: SidebarWorkspaceRowModel,
        focusAgentSurface: @escaping (UUID) -> Void = { _ in }
    ) -> SidebarWorkspaceRowTableCellView {
        let cell = SidebarWorkspaceRowTableCellView()
        cell.configure(
            model: model,
            actions: makeActions(model: model, focusAgentSurface: focusAgentSurface),
            isPointerHovering: false,
            contextMenuDidOpen: {},
            contextMenuDidClose: {}
        )
        return cell
    }

    private static func descendants(of view: NSView) -> [NSView] {
        view.subviews + view.subviews.flatMap { descendants(of: $0) }
    }

    private static func sessionLines(in cell: NSView) -> [SidebarRowAgentSessionLine] {
        descendants(of: cell).compactMap { $0 as? SidebarRowAgentSessionLine }.filter { !$0.isHidden }
    }

    @Test func sessionRowsAddHeightAndRenderOneLinePerSession() {
        let empty = Self.configuredCell(model: Self.makeModel(rows: []))
        let two = Self.configuredCell(model: Self.makeModel(rows: [Self.display(), Self.display()]))
        let emptyHeight = empty.layoutContent(model: Self.makeModel(rows: []), width: 300, apply: false)
        let twoHeight = two.layoutContent(model: Self.makeModel(rows: [Self.display(), Self.display()]), width: 300, apply: false)
        #expect(twoHeight > emptyHeight)
        #expect(Self.sessionLines(in: empty).isEmpty)
        #expect(Self.sessionLines(in: two).count == 2)
    }

    @Test func ageTicksDoNotChangeTheMeasuredHeight() {
        let a = Self.makeModel(rows: [Self.display(ageText: "12m")])
        let b = Self.makeModel(rows: [Self.display(ageText: "13m")])
        let cell = Self.configuredCell(model: a)
        let heightA = cell.layoutContent(model: a, width: 300, apply: false)
        cell.configure(
            model: b,
            actions: Self.makeActions(model: b),
            isPointerHovering: false,
            contextMenuDidOpen: {},
            contextMenuDidClose: {}
        )
        let heightB = cell.layoutContent(model: b, width: 300, apply: false)
        #expect(abs(heightA - heightB) < 0.5)
    }

    @Test func promptLineAndLongTitlesGrowTheRow() {
        let short = Self.makeModel(rows: [Self.display()])
        let withPrompt = Self.makeModel(rows: [Self.display(promptLine: "↳ fix the login bug")])
        let longTitle = Self.makeModel(rows: [Self.display(title: String(repeating: "training campaign ", count: 6))])
        let shortHeight = Self.configuredCell(model: short).layoutContent(model: short, width: 260, apply: false)
        let promptHeight = Self.configuredCell(model: withPrompt).layoutContent(model: withPrompt, width: 260, apply: false)
        let longHeight = Self.configuredCell(model: longTitle).layoutContent(model: longTitle, width: 260, apply: false)
        #expect(promptHeight > shortHeight)
        #expect(longHeight > shortHeight)
    }

    @Test func stateLivesInTheTitleColorAndBallsMarkAttention() throws {
        let model = Self.makeModel(rows: [
            Self.display(title: "Running one", state: .running),
            Self.display(title: "Idle one", state: .idle),
            Self.display(title: "Blocked one", state: .needsInput),
            Self.display(title: "Unread one", state: .idle, showsUnreadBall: true),
        ])
        let cell = Self.configuredCell(model: model)
        let lines = Self.sessionLines(in: cell)
        #expect(lines.count == 4)
        func titleField(_ line: SidebarRowAgentSessionLine, _ title: String) throws -> NSTextField {
            try #require(Self.descendants(of: line).compactMap { $0 as? NSTextField }.first { $0.stringValue == title })
        }
        let runningColor = SidebarRowAgentSessionLine.runningTitleColor(isActive: false, colorSchemeIsDark: true)
        let runningField = try titleField(lines[0], "Running one")
        let idleField = try titleField(lines[1], "Idle one")
        #expect(runningField.textColor == runningColor)
        #expect(idleField.textColor != runningColor)
        #expect(!lines[0].hasVisibleBall)
        #expect(!lines[1].hasVisibleBall)
        #expect(lines[2].hasVisibleBall)
        #expect(lines[3].hasVisibleBall)
    }

    @Test func recencyMarkersAppendToTheAgeColumn() {
        let model = Self.makeModel(rows: [
            Self.display(ageText: "<1m", recencyRank: 0),
            Self.display(ageText: "25m", recencyRank: 1),
            Self.display(ageText: "3h"),
        ])
        let lines = Self.sessionLines(in: Self.configuredCell(model: model))
        #expect(lines[0].ageDisplayText == "<1m ◀")
        #expect(lines[1].ageDisplayText == "25m ‹")
        #expect(lines[2].ageDisplayText == "3h")
    }

    @Test func pressingALineFocusesItsPaneWithoutSelectingTheRow() throws {
        let panelId = UUID()
        final class Focused: @unchecked Sendable { var panelIds: [UUID] = [] }
        let focused = Focused()
        let model = Self.makeModel(rows: [Self.display(panelId: panelId)])
        let cell = Self.configuredCell(model: model) { focused.panelIds.append($0) }
        let line = try #require(Self.sessionLines(in: cell).first)
        #expect(line.accessibilityPerformPress())
        #expect(focused.panelIds == [panelId])
        #expect(cell.selectionPreviewShouldIgnore(line))
    }

    @Test func groupOutlineSliceRendersOnlyForGroupedRows() {
        let grouped = Self.configuredCell(model: Self.makeModel(rows: [], groupFrameSegment: .middle, groupTintHex: "#BC5215"))
        let ungrouped = Self.configuredCell(model: Self.makeModel(rows: []))
        let groupedFrames = Self.descendants(of: grouped).compactMap { $0 as? SidebarGroupFrameSegmentView }
        let ungroupedFrames = Self.descendants(of: ungrouped).compactMap { $0 as? SidebarGroupFrameSegmentView }
        #expect(groupedFrames.contains { !$0.isHidden })
        #expect(ungroupedFrames.allSatisfy(\.isHidden))
    }
}
