import Foundation

/// Settings for the surface tab strip inside workspace panes (the `tabBar.*` keys).
public struct TabBarCatalogSection: SettingCatalogSection {
    /// `"fill"` stretches tabs across the pane's free width (one tab spans the
    /// whole bar; many tabs share it, then scroll). `"fixed"` keeps every tab
    /// at its natural width and scrolls the strip.
    public let widthMode = DefaultsKey<String>(
        id: "tabBar.widthMode",
        defaultValue: Self.widthModeDefault,
        userDefaultsKey: "tabBar.widthMode"
    )

    /// The widest a tab may grow, in points, before its title truncates.
    public let tabMaxWidth = DefaultsKey<Double>(
        id: "tabBar.tabMaxWidth",
        defaultValue: Self.tabMaxWidthDefault,
        userDefaultsKey: "tabBar.tabMaxWidth"
    )

    public static let widthModeDefault = "fill"
    public static let widthModeValues = ["fill", "fixed"]
    public static let tabMaxWidthDefault: Double = 360
    public static let tabMaxWidthMinimum: Double = 100
    public static let tabMaxWidthMaximum: Double = 1_000

    public init() {}
}
