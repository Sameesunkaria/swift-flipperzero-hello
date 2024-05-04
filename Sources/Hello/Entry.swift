import FlipperApplication

/// The main entry point of the application.
@_cdecl("entry")
public func entry(pointer: UnsafeMutableRawPointer?) -> UInt32 {
  withGUI { gui in
    let model = HelloModel()
    let viewPort = ViewPort(HelloView(model: model))
    gui.add(viewPort, layer: GuiLayerFullscreen)
    viewPort.update()

    let timer = Timer(type: FuriTimerTypePeriodic) {
      try? model.eventQueue.put(.timerTick)
    }
    timer.start(interval: furi_kernel_get_tick_frequency() / 6)

    eventLoop(model: model, viewPort: viewPort)

    timer.stop()
    viewPort.enabled(false)
    gui.remove(viewPort)
  }

  return 0
}

func eventLoop(model: HelloModel, viewPort: borrowing ViewPort) {
  var running = true
  while running {
    do {
      let event = try model.eventQueue.get(timeout: .ticks(100))
      if case let .input(inputEvent) = event,
        inputEvent.type == InputTypePress || inputEvent.type == InputTypeRepeat,
        inputEvent.key == InputKeyBack
      {
        running = false
      } else {
        let oldState = model.state
        model.handle(event: event)

        // Update the view if the state has changed
        if model.state != oldState {
          viewPort.update()
        }
      }
    } catch {
      if error.code != FuriStatusErrorTimeout {
        running = false
      }
    }
  }
}
