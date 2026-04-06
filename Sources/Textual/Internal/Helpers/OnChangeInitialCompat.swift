import SwiftUI

struct OnChangeInitialCompat<Value: Equatable>: ViewModifier {
  @State private var didSendInitialValue = false

  let value: Value
  let action: (Value) -> Void

  func body(content: Content) -> some View {
    content
      .onAppear {
        guard !didSendInitialValue else { return }
        didSendInitialValue = true
        action(value)
      }
      .onChange(of: value) { newValue in
        action(newValue)
      }
  }
}

extension View {
  func onChangeInitialCompat<Value: Equatable>(
    of value: Value,
    perform action: @escaping (Value) -> Void
  ) -> some View {
    modifier(OnChangeInitialCompat(value: value, action: action))
  }
}
