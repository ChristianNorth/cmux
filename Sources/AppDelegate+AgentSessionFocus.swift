import AppKit
import Foundation

/// Shared action path for the sidebar session rows, the `jumpToLastPrompt`
/// shortcut, and `cmux jump-to-last-prompt`: locate an agent session's pane
/// and focus it through the notification-open path (no selection flash).
@MainActor
extension AppDelegate {
    struct ResolvedAgentSession {
        let record: AgentChatSessionRecord
        let panelId: UUID
        let workspace: Workspace
        let tabManager: TabManager
    }

    /// The most recently typed-into live sessions whose panes still exist in
    /// some window, most recent first. Records are ordered by their last hook
    /// prompt; only those whose pane resolves count toward the limit. The
    /// record's stored workspace id is only a hint (it goes stale across
    /// relaunches), the pane binding is authoritative.
    func resolvedLastTypedAgentSessions(limit: Int) -> [ResolvedAgentSession] {
        guard limit > 0,
              let service = TerminalController.shared.agentChatTranscriptService else { return [] }
        var resolved: [ResolvedAgentSession] = []
        for record in service.lastTypedLiveSessions() {
            guard let panelId = record.surfaceID.flatMap(UUID.init(uuidString:)) else { continue }
            let preferredWorkspaceId = record.workspaceID.flatMap(UUID.init(uuidString:))
            guard let located = workspaceContainingPanel(panelId: panelId, preferredWorkspaceId: preferredWorkspaceId) else {
                continue
            }
            resolved.append(ResolvedAgentSession(
                record: record,
                panelId: panelId,
                workspace: located.workspace,
                tabManager: located.tabManager
            ))
            if resolved.count == limit { break }
        }
        return resolved
    }

    /// The single most recently typed-into live session, for the jump verbs.
    func resolvedLastTypedAgentSession() -> ResolvedAgentSession? {
        resolvedLastTypedAgentSessions(limit: 1).first
    }

    /// Selects the pane's workspace and focuses the pane, across windows.
    /// Returns false when no workspace owns the pane.
    @discardableResult
    func focusAgentSurface(panelId: UUID, preferredWorkspaceId: UUID?) -> Bool {
        guard let located = workspaceContainingPanel(panelId: panelId, preferredWorkspaceId: preferredWorkspaceId) else {
            return false
        }
        return focusTerminal(tabId: located.workspace.id, surfaceId: panelId)
    }

    /// Jumps to the session the user last typed into. Returns false (and
    /// beeps) when there is none.
    @discardableResult
    func jumpToLastPrompt() -> Bool {
        guard let session = resolvedLastTypedAgentSession(),
              focusAgentSurface(panelId: session.panelId, preferredWorkspaceId: session.workspace.id) else {
            NSSound.beep()
            return false
        }
        return true
    }
}
