import Bonsplit
import CmuxSettings
import Foundation
import Testing

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

@Suite("Tab bar settings file", .serialized)
struct TabBarSettingsFileStoreTests {
    private let settingsFileBackupsDefaultsKey = "cmux.settingsFile.backups.v1"
    private let importedManagedDefaultsKey = "cmux.settingsFile.importedManagedDefaults.v1"

    @Test
    func defaultsAreFillModeAndThreeSixtyPoints() throws {
        try withCleanDefaults { defaults in
            #expect(TabBarSettings.widthMode(defaults: defaults) == .fill)
            #expect(TabBarSettings.tabMaxWidth(defaults: defaults) == 360)
            #expect(TabBarSettings.WidthMode.fill.bonsplitMode == .fill)
            #expect(TabBarSettings.WidthMode.fixed.bonsplitMode == .fixed)
        }
    }

    @Test
    func settingsFileAppliesWidthModeAndMaxWidth() throws {
        try loadTabBarSection(#"{ "widthMode": "fixed", "tabMaxWidth": 280 }"#) { defaults in
            #expect(TabBarSettings.widthMode(defaults: defaults) == .fixed)
            #expect(TabBarSettings.tabMaxWidth(defaults: defaults) == 280)
        }
    }

    @Test
    func settingsFileClampsMaxWidthAndIgnoresUnknownModes() throws {
        try loadTabBarSection(#"{ "widthMode": "stretchy", "tabMaxWidth": 5000 }"#) { defaults in
            #expect(TabBarSettings.widthMode(defaults: defaults) == .fill)
            #expect(TabBarSettings.tabMaxWidth(defaults: defaults) == TabBarCatalogSection.tabMaxWidthMaximum)
        }
    }

    @Test
    func sanitizedMaxWidthBounds() {
        #expect(TabBarSettings.sanitizedTabMaxWidth(50) == TabBarCatalogSection.tabMaxWidthMinimum)
        #expect(TabBarSettings.sanitizedTabMaxWidth(.nan) == TabBarCatalogSection.tabMaxWidthDefault)
        #expect(TabBarSettings.sanitizedTabMaxWidth(420) == 420)
    }

    private func loadTabBarSection(_ json: String, verify: (UserDefaults) throws -> Void) throws {
        try withCleanDefaults { defaults in
            let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(
                "cmux-tab-bar-settings-\(UUID().uuidString)",
                isDirectory: true
            )
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directoryURL) }

            let settingsFileURL = directoryURL.appendingPathComponent("cmux.json", isDirectory: false)
            try """
            {
              "tabBar": \(json)
            }
            """.write(to: settingsFileURL, atomically: true, encoding: .utf8)

            _ = KeyboardShortcutSettingsFileStore(
                primaryPath: settingsFileURL.path,
                fallbackPath: nil,
                additionalFallbackPaths: [],
                startWatching: false
            )

            try verify(defaults)
        }
    }

    private func withCleanDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let defaults = UserDefaults.standard
        let keys = [
            TabBarSettings.widthModeKey,
            TabBarSettings.tabMaxWidthKey,
            settingsFileBackupsDefaultsKey,
            importedManagedDefaultsKey,
        ]
        let saved = keys.map { ($0, defaults.object(forKey: $0)) }
        for key in keys { defaults.removeObject(forKey: key) }
        defer {
            for (key, value) in saved {
                if let value {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }
        try body(defaults)
    }
}
