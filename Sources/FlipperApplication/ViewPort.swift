import CFlipperApplication

public struct ViewPort: ~Copyable {
  private enum Storage {
    case borrowed(viewPortPointer: OpaquePointer)
    case owned(viewPortPointer: OpaquePointer, contextPointer: UnsafeMutablePointer<Context>)
  }

  private struct Context: ~Copyable {
    var view: AnyView
    var viewPort: ViewPort
  }

  private var storage: Storage

  public init(borrowing viewPort: OpaquePointer) {
    storage = .borrowed(viewPortPointer: viewPort)
  }

  public init<V: View>(_ view: V) {
    let viewPortPointer = view_port_alloc().unsafelyUnwrapped
    let contextPointer = UnsafeMutablePointer<Context>.allocate(capacity: 1)
    storage = .owned(viewPortPointer: viewPortPointer, contextPointer: contextPointer)

    contextPointer.pointee = Context(view: AnyView(view), viewPort: ViewPort(borrowing: viewPortPointer))
    view_port_draw_callback_set(viewPortPointer, appDrawCallback, contextPointer)
    view_port_input_callback_set(viewPortPointer, appInputCallback, contextPointer)
  }

  deinit {
    if case let .owned(viewPortPointer, contextPointer) = storage {
      view_port_free(viewPortPointer)
      contextPointer.deallocate()
    }
  }

  typealias DrawCallback = @convention(c) (OpaquePointer?, UnsafeMutableRawPointer?) -> Void
  private let appDrawCallback: DrawCallback = { canvas, contextPointer in
    contextPointer.unsafelyUnwrapped.withMemoryRebound(to: Context.self, capacity: 1) { contextPointer in
      let viewPort = ViewPort(borrowing: contextPointer.pointee.viewPort.pointer)
      contextPointer.pointee.view.draw(
        canvas: Canvas(borrowing: canvas.unsafelyUnwrapped),
        context: ViewContext(viewPort: viewPort)
      )
    }
  }

  typealias InputCallback = @convention(c) (UnsafeMutablePointer<InputEvent>?, UnsafeMutableRawPointer?) -> Void
  private let appInputCallback: InputCallback = { inputEvent, contextPointer in
    contextPointer.unsafelyUnwrapped.withMemoryRebound(to: Context.self, capacity: 1) { contextPointer in
      let viewPort = ViewPort(borrowing: contextPointer.pointee.viewPort.pointer)
      contextPointer.pointee.view.receivedInput(
        event: inputEvent.unsafelyUnwrapped.pointee,
        context: ViewContext(viewPort: viewPort)
      )
    }
  }

  public var pointer: OpaquePointer {
    switch storage {
    case .borrowed(let viewPortPointer):
      return viewPortPointer
    case .owned(let viewPortPointer, _):
      return viewPortPointer
    }
  }

  public func update() {
    view_port_update(pointer)
  }

  public func enabled(_ enabled: Bool) {
    view_port_enabled_set(pointer, enabled)
  }
}
