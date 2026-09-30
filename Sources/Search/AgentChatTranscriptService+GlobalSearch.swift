import CmuxAgentChat
import CmuxMobileHost
import Foundation

extension AgentChatTranscriptService {
    /// The live Claude or Codex session in a pane, as Global Search indexes it.
    ///
    /// Only the resolver's `boundedTranscriptPath` is read: the path the
    /// agent's hook recorded, or Claude's own project file for the session.
    /// Returns nil for panes without a live session or a readable transcript.
    func globalSearchSource(surfaceID: UUID, paneTitle: String) -> AgentSessionSearchSource? {
        guard let record = liveSessionRecord(surfaceID: surfaceID.uuidString) else { return nil }
        switch record.agentKind {
        case .claude, .codex:
            break
        case .other:
            return nil
        }
        guard let path = resolver.boundedTranscriptPath(for: record) else { return nil }
        return AgentSessionSearchSource(
            sessionID: record.sessionID,
            agentKind: record.agentKind,
            transcriptPath: path,
            title: SidebarAgentSessionSnapshotBuilder.resolvedTitle(
                aiTitle: record.aiTitle,
                paneTitle: paneTitle,
                agentName: record.agentKind.displayName
            ),
            workingDirectory: record.workingDirectory
        )
    }
}
