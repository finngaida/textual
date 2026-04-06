public enum TextSelectionMode: Hashable, Sendable {
  case disabled
  case enabled

  var allowsSelection: Bool {
    switch self {
    case .disabled:
      return false
    case .enabled:
      return true
    }
  }
}
