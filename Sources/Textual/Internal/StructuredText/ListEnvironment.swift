import SwiftUI

extension EnvironmentValues {
  var listItemSpacing: FontScaled<StructuredText.BlockSpacing> {
    get { self[ListItemSpacingKey.self] }
    set { self[ListItemSpacingKey.self] = newValue }
  }

  var resolvedListItemSpacing: StructuredText.BlockSpacing {
    get { self[ResolvedListItemSpacingKey.self] }
    set { self[ResolvedListItemSpacingKey.self] = newValue }
  }

  var listItemSpacingEnabled: Bool {
    get { self[ListItemSpacingEnabledKey.self] }
    set { self[ListItemSpacingEnabledKey.self] = newValue }
  }
}

private struct ListItemSpacingKey: EnvironmentKey {
  static var defaultValue: FontScaled<StructuredText.BlockSpacing> { .fontScaled(top: 0.25) }
}

private struct ResolvedListItemSpacingKey: EnvironmentKey {
  static var defaultValue: StructuredText.BlockSpacing { StructuredText.BlockSpacing() }
}

private struct ListItemSpacingEnabledKey: EnvironmentKey {
  static var defaultValue: Bool { false }
}
