import Foundation

/// One rendered session row: what the AppKit line draws, already formatted.
/// Part of `SidebarWorkspaceRowModel`, so it is Equatable and drives both the
/// live cell and the height-cache prototype.
struct SidebarRowAgentSessionDisplay: Equatable, Identifiable {
    /// Recency markers for the three sessions the user most recently typed
    /// into: a full arrow on the most recent, chevrons on the next two.
    static func markerGlyph(forRecencyRank rank: Int) -> String {
        rank == 0 ? "◀" : "‹"
    }
    /// Prefix of the last-prompt line.
    static let promptPrefix = "↳ "

    let panelId: UUID
    var id: UUID { panelId }
    /// 1-based position within the workspace's session list; the leading
    /// gutter shows it unless an attention ball takes its place.
    var ordinal: Int = 1
    let title: String
    let state: SidebarAgentSessionSnapshot.State
    /// "12m"; the marker glyph is appended by the line view in its own color.
    /// `var` only so `neutralizingAge()` can blank it for height comparisons.
    var ageText: String
    /// 0, 1 or 2 when this is one of the three sessions the user most
    /// recently typed into (0 = most recent); nil otherwise.
    let recencyRank: Int?
    /// A finished (idle) session with an unread turn-end notification draws a
    /// blue ball until its pane is focused.
    let showsUnreadBall: Bool
    /// "↳ <prompt>", nil when the prompt line is hidden for this row.
    let promptLine: String?
    /// Full title, blank line, full prompt (title only without a prompt).
    let toolTip: String
    let accessibilityLabel: String

    /// The same row with the ticking age removed, for height equivalence.
    func neutralizingAge() -> Self {
        var copy = self
        copy.ageText = ""
        return copy
    }
}

/// Turns workspace session snapshots into display rows for one point in time.
struct SidebarRowAgentSessionPresenter {
    let now: Date
    /// Panels of the sessions the user most recently typed into, most recent
    /// first, at most three.
    let lastTypedPanelIds: [UUID]
    /// Panels with an unread notification (turn finished while unfocused).
    var unreadPanelIds: Set<UUID> = []
    var formatter = SidebarAgentSessionAgeFormatter()

    /// - Parameter isActive: whether the workspace is the selected one; the
    ///   prompt line shows for every session of the selected workspace and for
    ///   the most recently typed-into session anywhere.
    func rows(for sessions: [SidebarAgentSessionSnapshot], isActive: Bool) -> [SidebarRowAgentSessionDisplay] {
        sessions.enumerated().map { index, session in
            let rank = lastTypedPanelIds.firstIndex(of: session.panelId)
            let prompt = session.lastPrompt?.trimmingCharacters(in: .whitespacesAndNewlines)
            let promptLine: String? = {
                guard isActive || rank == 0, let prompt, !prompt.isEmpty else { return nil }
                return SidebarRowAgentSessionDisplay.promptPrefix + prompt
            }()
            let toolTip = prompt.map { "\(session.title)\n\n\($0)" } ?? session.title
            let stateLabel: String
            switch session.state {
            case .running:
                stateLabel = String(localized: "sidebar.agentSession.state.running", defaultValue: "running")
            case .idle:
                stateLabel = String(localized: "sidebar.agentSession.state.idle", defaultValue: "idle")
            case .needsInput:
                stateLabel = String(localized: "sidebar.agentSession.state.needsInput", defaultValue: "needs input")
            }
            let showsUnreadBall = session.state == .idle && unreadPanelIds.contains(session.panelId)
            return SidebarRowAgentSessionDisplay(
                panelId: session.panelId,
                ordinal: index + 1,
                title: session.title,
                state: session.state,
                ageText: formatter.text(from: session.lastActivityMinute, now: now),
                recencyRank: rank,
                showsUnreadBall: showsUnreadBall,
                promptLine: promptLine,
                toolTip: toolTip,
                accessibilityLabel: showsUnreadBall
                    ? "\(session.agentName): \(session.title), \(stateLabel), unread"
                    : "\(session.agentName): \(session.title), \(stateLabel)"
            )
        }
    }
}
