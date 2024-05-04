import CFlipperApplication

public struct ViewContext: ~Copyable {
  /// The `ViewPort` that the `View` is being drawn in.
  public var viewPort: ViewPort
}

public protocol View {
  /// Update the `Canvas`. Always called on the GUI thread.
  func draw(canvas: Canvas, context: borrowing ViewContext)

  /// Handle an input event. Always called on the GUI thread.
  func receivedInput(event: InputEvent, context: borrowing ViewContext)
}

public struct AnyView: View {
  private var draw: (Canvas, borrowing ViewContext) -> Void
  private var receivedInput: (InputEvent, borrowing ViewContext) -> Void

  public init<V: View>(_ view: V) {
    draw = view.draw
    receivedInput = view.receivedInput
  }

  public func draw(canvas: Canvas, context: borrowing ViewContext) {
    draw(canvas, context)
  }

  public func receivedInput(event: InputEvent, context: borrowing ViewContext) {
    receivedInput(event, context)
  }
}
