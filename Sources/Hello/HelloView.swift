import FlipperApplication

final class HelloModel {
  enum AnimationDirection: Hashable {
    case up
    case down

    var reversed: Self {
      self == .up ? .down : .up
    }
  }

  enum Event {
    case input(InputEvent)
    case timerTick
    case animationDirectionChanged(AnimationDirection)
  }

  struct State: Hashable {
    var textPosition = Point(x: 58, y: 8)
    var stepSize: Int32 = 2
    var textAnimationDirection: AnimationDirection = .down
    var showsFreeMemory: Bool = false
  }

  let eventQueue = MessageQueue<Event>(capacity: 8)
  var state = State()

  /// The single point of entry for mutating the state of the model.
  func handle(event: Event) {
    switch event {
    case .input(let inputEvent):
      handleInput(inputEvent)
    case .timerTick:
      state.textPosition.y += (state.textAnimationDirection == .down) ? 1 : -1
    case .animationDirectionChanged(let direction):
      Logger.logInfo("handle .animationDirectionChanged")
      state.textAnimationDirection = direction
    }
  }

  private func handleInput(_ inputEvent: InputEvent) {
    if inputEvent.type == InputTypePress || inputEvent.type == InputTypeRepeat {
      switch inputEvent.key {
      case InputKeyLeft:
        state.textPosition.x -= state.stepSize
      case InputKeyRight:
        state.textPosition.x += state.stepSize
      case InputKeyUp:
        state.textPosition.y -= state.stepSize
      case InputKeyDown:
        state.textPosition.y += state.stepSize
        var s = Set([1,2,3])
        s.insert(4)
      case InputKeyOk:
        state.showsFreeMemory.toggle()
      default:
        break
      }
    }
  }
}

struct HelloView: View {
  var model: HelloModel

  func draw(canvas: Canvas, context: borrowing ViewContext) {
    canvas.clear()

    // Draw the Swift logo.
    canvas.drawIcon(
      swiftIcon,
      at: Point(x: 0, y: Int32((canvas.height - swiftIconSize) / 2)),
      width: UInt8(swiftIconSize),
      height: UInt8(swiftIconSize)
    )

    // Display the free memory when enabled.
    if model.state.showsFreeMemory {
      let freeMemory = freeMemoryString()
      canvas_draw_str_aligned(canvas.pointer, 0, 0, AlignLeft, AlignTop, freeMemory)
      freeMemory.deallocate()
    }

    // Display "Hello, Swift!".
    canvas.setFont(FontPrimary)
    canvas.drawText("Hello, Swift!", at: model.state.textPosition, verticalAlignment: AlignTop)

    // Change the text animation direction when it reaches the top or bottom edges of the screen.
    if model.state.textPosition.y > Int32(canvas.height - canvas.currentFontHeight) {
      try? model.eventQueue.put(.animationDirectionChanged(.up))
    } else if model.state.textPosition.y <= 0 {
      try? model.eventQueue.put(.animationDirectionChanged(.down))
    }
  }

  func receivedInput(event: InputEvent, context: borrowing ViewContext) {
    try? model.eventQueue.put(.input(event))
  }

  private func freeMemoryString() -> UnsafeMutablePointer<CChar> {
    let cString = UnsafeMutablePointer<Int8>.allocate(capacity: 16)
    let freeMemory = memmgr_get_free_heap()
    itoa(CInt(freeMemory), cString, 10)
    return cString
  }
}
