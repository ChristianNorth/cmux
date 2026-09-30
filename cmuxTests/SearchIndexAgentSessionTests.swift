import XCTest

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

/// Ranking and row collapsing that vibe search relies on.
final class SearchIndexAgentSessionTests: XCTestCase {
    func testPanelShowsOneRowAndPrefersItsSessionDocumentOverItsTitle() async throws {
        let (directory, index) = try makeIndex()
        defer { try? FileManager.default.removeItem(at: directory) }
        let panelID = UUID()

        try await index.upsert(document(
            id: SearchIndexDocument.panelStableID(panelID: panelID, kind: .title),
            panelID: panelID,
            kind: .title,
            title: "Token spend review",
            text: "Window 1\ncommand center\nToken spend review"
        ))
        try await index.upsert(document(
            id: SearchIndexDocument.panelStableID(panelID: panelID, kind: .agentSession),
            panelID: panelID,
            kind: .agentSession,
            title: "Token spend review",
            text: "how much did the delphi token spend come to last week"
        ))

        let hits = try await index.search("token spend", limit: 10)
        XCTAssertEqual(hits.map(\.kind), [.agentSession])
        XCTAssertEqual(hits.first?.panelID, panelID)
        XCTAssertTrue(hits.first?.snippet.contains("delphi token spend") ?? false, "\(hits)")
    }

    func testTitleMatchOutranksOneMentionInALongBody() async throws {
        let (directory, index) = try makeIndex()
        defer { try? FileManager.default.removeItem(at: directory) }
        let titled = UUID()
        let mentioned = UUID()

        try await index.upsert(document(
            id: "titled",
            panelID: titled,
            kind: .agentSession,
            title: "User access permissions",
            text: String(repeating: "reviewing the grant list for the team. ", count: 200)
        ))
        try await index.upsert(document(
            id: "mentioned",
            panelID: mentioned,
            kind: .agentSession,
            title: "Snapshot QA",
            text: "one line about access. " + String(repeating: "snapshot rows compared. ", count: 200)
        ))

        let hits = try await index.search("access", limit: 10)
        XCTAssertEqual(hits.map(\.id), ["titled", "mentioned"])
    }

    func testPrefixQueryMatchesAWordBeingTyped() async throws {
        let (directory, index) = try makeIndex()
        defer { try? FileManager.default.removeItem(at: directory) }
        let panelID = UUID()
        try await index.upsert(document(
            id: "deeptune",
            panelID: panelID,
            kind: .agentSession,
            title: "Add initiative to DeepTune",
            text: "set up the DeepTune vision verticals pod"
        ))

        let hits = try await index.search("deept", limit: 10)
        XCTAssertEqual(hits.map(\.id), ["deeptune"])
        XCTAssertTrue(hits.first?.snippet.contains("DeepTune") ?? false, "\(hits)")
    }

    func testOnePerPanelKeepsBestRankOrderAndPanelLessRows() {
        let first = UUID()
        let second = UUID()
        let hits = [
            hit(id: "a-title", panelID: first, kind: .title),
            hit(id: "b-session", panelID: second, kind: .agentSession),
            hit(id: "loose", panelID: nil, kind: .browser),
            hit(id: "a-session", panelID: first, kind: .agentSession),
            hit(id: "b-title", panelID: second, kind: .title),
        ]
        XCTAssertEqual(
            SearchIndex.onePerPanel(hits, limit: 10).map(\.id),
            ["a-session", "b-session", "loose"]
        )
        XCTAssertEqual(SearchIndex.onePerPanel(hits, limit: 2).map(\.id), ["a-session", "b-session"])
    }

    func testAgentSessionDocumentUsesSessionTitleAndLeadsWithTheDirectory() {
        let source = AgentSessionSearchSource(
            sessionID: "s-1",
            agentKind: .claude,
            transcriptPath: "/tmp/s-1.jsonl",
            title: "Env linter eval cost estimate",
            workingDirectory: "/Users/me/cc-sparta"
        )
        let panelID = UUID()
        let document = GlobalSearchDocuments.agentSessionDocument(
            windowID: UUID(),
            workspaceID: UUID(),
            panelID: panelID,
            location: "Window 1 > research pod",
            source: source,
            transcriptText: "what would the eval cost"
        )
        XCTAssertEqual(document.id, SearchIndexDocument.panelStableID(panelID: panelID, kind: .agentSession))
        XCTAssertEqual(document.kind, .agentSession)
        XCTAssertEqual(document.title, "Env linter eval cost estimate")
        XCTAssertEqual(document.location, "Window 1 > research pod")
        XCTAssertEqual(document.anchor, "s-1")
        XCTAssertEqual(document.text, "/Users/me/cc-sparta\nwhat would the eval cost")
    }

    // MARK: - Fixtures

    private func makeIndex() throws -> (URL, SearchIndex) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("cmux-search-agent-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let index = try SearchIndex(databaseURL: directory.appendingPathComponent("search.db", isDirectory: false))
        return (directory, index)
    }

    private let windowID = UUID()
    private let workspaceID = UUID()

    private func document(
        id: String,
        panelID: UUID,
        kind: GlobalSearchKind,
        title: String,
        text: String
    ) -> SearchIndexDocument {
        SearchIndexDocument(
            id: id,
            windowID: windowID,
            workspaceID: workspaceID,
            panelID: panelID,
            kind: kind,
            title: title,
            location: "Window 1 > workspace",
            anchor: kind.rawValue,
            text: text
        )
    }

    private func hit(id: String, panelID: UUID?, kind: GlobalSearchKind) -> SearchIndexHit {
        SearchIndexHit(
            id: id,
            windowID: windowID,
            workspaceID: workspaceID,
            panelID: panelID,
            kind: kind,
            title: id,
            location: "",
            anchor: "",
            snippet: "",
            rank: 0,
            timestamp: Date(timeIntervalSince1970: 0)
        )
    }
}
