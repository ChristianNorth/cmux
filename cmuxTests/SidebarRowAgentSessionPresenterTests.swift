import CmuxSidebar
import Foundation
import Testing

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

struct SidebarAgentSessionAgeFormatterTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)
    private let formatter = SidebarAgentSessionAgeFormatter()

    private func age(_ secondsAgo: TimeInterval) -> String {
        formatter.text(from: now.addingTimeInterval(-secondsAgo), now: now)
    }

    @Test func boundaries() {
        #expect(age(30) == "<1m")
        #expect(age(59) == "<1m")
        #expect(age(60) == "1m")
        #expect(age(12 * 60) == "12m")
        #expect(age(59 * 60 + 59) == "59m")
        #expect(age(3_600) == "1h")
        #expect(age(23 * 3_600 + 59 * 60) == "23h")
        #expect(age(86_400) == "1d")
        #expect(age(2 * 86_400) == "2d")
    }

    @Test func futureDatesReadAsUnderAMinute() {
        #expect(age(-120) == "<1m")
    }
}

struct SidebarRowAgentSessionPresenterTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func session(
        panelId: UUID = UUID(),
        title: String = "Fix the login bug",
        lastPrompt: String? = "fix the login bug",
        state: SidebarAgentSessionSnapshot.State = .running,
        minutesAgo: TimeInterval = 12
    ) -> SidebarAgentSessionSnapshot {
        SidebarAgentSessionSnapshot(
            panelId: panelId,
            sessionID: "s-\(panelId.uuidString.prefix(4))",
            agentName: "Claude",
            title: title,
            lastPrompt: lastPrompt,
            lastPromptAt: now.addingTimeInterval(-minutesAgo * 60),
            state: state,
            lastActivityMinute: now.addingTimeInterval(-minutesAgo * 60)
        )
    }

    @Test func promptLineHiddenOnInactiveWorkspaces() {
        let rows = SidebarRowAgentSessionPresenter(now: now, lastTypedPanelIds: [])
            .rows(for: [session()], isActive: false)
        #expect(rows.count == 1)
        #expect(rows[0].promptLine == nil)
        #expect(rows[0].ageText == "12m")
        #expect(rows[0].recencyRank == nil)
        #expect(rows[0].toolTip == "Fix the login bug\n\nfix the login bug")
    }

    @Test func promptLineShownOnTheActiveWorkspace() {
        let rows = SidebarRowAgentSessionPresenter(now: now, lastTypedPanelIds: [])
            .rows(for: [session()], isActive: true)
        #expect(rows[0].promptLine == "↳ fix the login bug")
    }

    @Test func recencyRanksFollowTheLastTypedOrder() {
        let first = UUID(), second = UUID(), third = UUID(), other = UUID()
        let rows = SidebarRowAgentSessionPresenter(now: now, lastTypedPanelIds: [first, second, third])
            .rows(
                for: [session(panelId: third), session(panelId: other), session(panelId: first), session(panelId: second)],
                isActive: false
            )
        #expect(rows.map(\.recencyRank) == [2, nil, 0, 1])
        #expect(SidebarRowAgentSessionDisplay.markerGlyph(forRecencyRank: 0) == "◀")
        #expect(SidebarRowAgentSessionDisplay.markerGlyph(forRecencyRank: 1) == "‹")
        #expect(SidebarRowAgentSessionDisplay.markerGlyph(forRecencyRank: 2) == "‹")
    }

    @Test func onlyTheMostRecentSessionShowsItsPromptWhenInactive() {
        let first = UUID(), second = UUID()
        let rows = SidebarRowAgentSessionPresenter(now: now, lastTypedPanelIds: [first, second])
            .rows(for: [session(panelId: first), session(panelId: second)], isActive: false)
        #expect(rows[0].promptLine == "↳ fix the login bug")
        #expect(rows[1].promptLine == nil)
    }

    @Test func unreadBallShowsOnlyForIdleSessionsWithUnreadNotifications() {
        let idleUnread = UUID(), runningUnread = UUID(), idleRead = UUID()
        var presenter = SidebarRowAgentSessionPresenter(now: now, lastTypedPanelIds: [])
        presenter.unreadPanelIds = [idleUnread, runningUnread]
        let rows = presenter.rows(
            for: [
                session(panelId: idleUnread, state: .idle),
                session(panelId: runningUnread, state: .running),
                session(panelId: idleRead, state: .idle),
            ],
            isActive: false
        )
        #expect(rows.map(\.showsUnreadBall) == [true, false, false])
        #expect(rows[0].accessibilityLabel.hasSuffix("unread"))
    }

    @Test func missingPromptYieldsNoPromptLineAndATitleOnlyTooltip() {
        let rows = SidebarRowAgentSessionPresenter(now: now, lastTypedPanelIds: [])
            .rows(for: [session(lastPrompt: nil)], isActive: true)
        #expect(rows[0].promptLine == nil)
        #expect(rows[0].toolTip == "Fix the login bug")
    }
}

struct SidebarWorkspaceRowModelAgentSessionTests {
    private func display(ageText: String, promptLine: String?) -> SidebarRowAgentSessionDisplay {
        SidebarRowAgentSessionDisplay(
            panelId: UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!,
            title: "Title",
            state: .idle,
            ageText: ageText,
            recencyRank: nil,
            showsUnreadBall: false,
            promptLine: promptLine,
            toolTip: "Title",
            accessibilityLabel: "Claude: Title, idle"
        )
    }

    private func model(rows: [SidebarRowAgentSessionDisplay], groupFrameSegment: SidebarGroupFrameSegment? = nil) -> SidebarWorkspaceRowModel {
        let settings = SidebarTabItemSettingsSnapshot(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let snapshot = SidebarWorkspaceSnapshotRefreshPolicyTests.snapshot()
        return SidebarWorkspaceRowModel(
            workspaceId: UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000001")!,
            index: 0,
            snapshot: snapshot,
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
            groupFrameSegment: groupFrameSegment
        )
    }

    @Test func ageTicksAreHeightEquivalentButNotEqual() {
        let a = model(rows: [display(ageText: "12m", promptLine: nil)])
        let b = model(rows: [display(ageText: "13m", promptLine: nil)])
        #expect(a != b)
        #expect(a.hasHeightEquivalentContent(to: b))
    }

    @Test func promptLinePresenceChangesHeightEquivalence() {
        let a = model(rows: [display(ageText: "12m", promptLine: nil)])
        let b = model(rows: [display(ageText: "12m", promptLine: "↳ prompt")])
        #expect(!a.hasHeightEquivalentContent(to: b))
    }

    @Test func groupFrameSegmentsAreHeightEquivalent() {
        let a = model(rows: [], groupFrameSegment: .middle)
        let b = model(rows: [], groupFrameSegment: .bottom)
        #expect(a != b)
        #expect(a.hasHeightEquivalentContent(to: b))
    }
}

struct SidebarGroupFrameSegmentAssemblyTests {
    @Test func headerOpensMembersContinueAndTheLastMemberCloses() {
        let group = UUID(), a = UUID(), b = UUID(), loose = UUID()
        let items: [SidebarWorkspaceRenderItem] = [
            .groupHeader(groupId: group, anchorWorkspaceId: a),
            .workspace(workspaceId: a),
            .workspace(workspaceId: b),
            .workspace(workspaceId: loose),
        ]
        let segments = SidebarGroupFrameSegment.segments(
            forRenderItems: items,
            groupIdByWorkspaceId: [a: group, b: group, loose: nil],
            collapsedGroupIds: []
        )
        #expect(segments == [.top, .middle, .bottom, nil])
    }

    @Test func collapsedAndEmptyGroupsDrawTheWholeRectangle() {
        let collapsed = UUID(), empty = UUID(), member = UUID()
        let items: [SidebarWorkspaceRenderItem] = [
            .groupHeader(groupId: collapsed, anchorWorkspaceId: member),
            .groupHeader(groupId: empty, anchorWorkspaceId: member),
            .workspace(workspaceId: member),
        ]
        let segments = SidebarGroupFrameSegment.segments(
            forRenderItems: items,
            groupIdByWorkspaceId: [member: nil],
            collapsedGroupIds: [collapsed]
        )
        #expect(segments == [.solo, .solo, nil])
    }

    @Test func adjacentGroupsCloseAtTheBoundary() {
        let g1 = UUID(), g2 = UUID(), a = UUID(), b = UUID()
        let items: [SidebarWorkspaceRenderItem] = [
            .groupHeader(groupId: g1, anchorWorkspaceId: a),
            .workspace(workspaceId: a),
            .groupHeader(groupId: g2, anchorWorkspaceId: b),
            .workspace(workspaceId: b),
        ]
        let segments = SidebarGroupFrameSegment.segments(
            forRenderItems: items,
            groupIdByWorkspaceId: [a: g1, b: g2],
            collapsedGroupIds: []
        )
        #expect(segments == [.top, .bottom, .top, .bottom])
    }
}

struct SidebarAgentStatusPillFilterTests {
    private func entry(_ key: String) -> SidebarStatusEntry {
        SidebarStatusEntry(key: key, value: "Running")
    }

    @Test func agentLifecycleAndFeedAttentionPillsAreHiddenWithSessionRowsOn() {
        let entries = [entry("claude_code"), entry("codex"), entry("cmux.feed.attention:claude_code"), entry("deploy")]
        let filtered = SidebarWorkspaceSnapshotFactory.filteredStatusEntries(entries, showsAgentSessions: true)
        #expect(filtered.map(\.key) == ["deploy"])
    }

    @Test func everythingPassesThroughWithSessionRowsOff() {
        let entries = [entry("claude_code"), entry("deploy")]
        let filtered = SidebarWorkspaceSnapshotFactory.filteredStatusEntries(entries, showsAgentSessions: false)
        #expect(filtered.map(\.key) == ["claude_code", "deploy"])
    }
}
