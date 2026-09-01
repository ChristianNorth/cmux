import Bonsplit
import CmuxSettings
import CoreGraphics
import Foundation

/// App-side accessors for the `tabBar.*` settings that shape the pane tab strip.
enum TabBarSettings {
    enum WidthMode: String {
        case fill
        case fixed

        var bonsplitMode: BonsplitConfiguration.Appearance.TabWidthMode {
            switch self {
            case .fill: return .fill
            case .fixed: return .fixed
            }
        }
    }

    static let widthModeKey = TabBarCatalogSection().widthMode.userDefaultsKey
    static let tabMaxWidthKey = TabBarCatalogSection().tabMaxWidth.userDefaultsKey
    static let didChangeNotification = Notification.Name("cmux.tabBarSettingsDidChange")

    nonisolated static func widthMode(defaults: UserDefaults = .standard) -> WidthMode {
        guard let raw = defaults.string(forKey: widthModeKey),
              let mode = WidthMode(rawValue: raw) else {
            return WidthMode(rawValue: TabBarCatalogSection.widthModeDefault) ?? .fill
        }
        return mode
    }

    nonisolated static func tabMaxWidth(defaults: UserDefaults = .standard) -> CGFloat {
        guard defaults.object(forKey: tabMaxWidthKey) != nil else {
            return CGFloat(TabBarCatalogSection.tabMaxWidthDefault)
        }
        return CGFloat(sanitizedTabMaxWidth(defaults.double(forKey: tabMaxWidthKey)))
    }

    nonisolated static func sanitizedTabMaxWidth(_ value: Double) -> Double {
        guard value.isFinite else { return TabBarCatalogSection.tabMaxWidthDefault }
        return min(max(value, TabBarCatalogSection.tabMaxWidthMinimum), TabBarCatalogSection.tabMaxWidthMaximum)
    }

    static func notifyDidChange(notificationCenter: NotificationCenter = .default) {
        notificationCenter.post(name: didChangeNotification, object: nil)
    }
}
