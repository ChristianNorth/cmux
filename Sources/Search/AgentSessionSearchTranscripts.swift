import CmuxAgentChat
import Foundation

/// A live agent session as Global Search indexes it.
struct AgentSessionSearchSource: Sendable, Equatable {
    let sessionID: String
    let agentKind: ChatAgentKind
    /// A transcript path the resolver vouched for (`boundedTranscriptPath`).
    let transcriptPath: String
    /// The name the sidebar shows for the session.
    let title: String
    let workingDirectory: String?
}

/// Owns one incremental transcript reader per indexed agent session and runs
/// their file reads and parsing off the main actor.
actor AgentSessionSearchTranscripts {
    private var readers: [String: AgentSessionSearchTranscript] = [:]
    private var revisions: [String: Int] = [:]
    private var nextRevision = 1

    /// Reads the session's new transcript bytes.
    ///
    /// - Returns: A revision that changes whenever the session's text changes
    ///   (unique across sessions), or nil while the transcript has no text.
    func refreshedRevision(for source: AgentSessionSearchSource) -> Int? {
        var reader = readers[source.sessionID]
        if reader?.path != source.transcriptPath || reader?.agentKind != source.agentKind {
            reader = AgentSessionSearchTranscript(path: source.transcriptPath, agentKind: source.agentKind)
            revisions[source.sessionID] = nil
        }
        guard var reader else { return nil }
        if reader.refresh() || revisions[source.sessionID] == nil {
            revisions[source.sessionID] = nextRevision
            nextRevision += 1
        }
        readers[source.sessionID] = reader
        return reader.text.isEmpty ? nil : revisions[source.sessionID]
    }

    /// The session's current document text, as of the last refresh.
    func text(forSessionID sessionID: String) -> String? {
        guard let text = readers[sessionID]?.text, !text.isEmpty else { return nil }
        return text.documentText
    }

    /// Drops readers for sessions no longer indexed.
    func retainOnly(sessionIDs: Set<String>) {
        readers = readers.filter { sessionIDs.contains($0.key) }
        revisions = revisions.filter { sessionIDs.contains($0.key) }
    }
}
