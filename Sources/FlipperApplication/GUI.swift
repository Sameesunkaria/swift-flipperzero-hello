import CFlipperApplication

/// Opens a GUI record and performs the given operation.
/// The GUI record is automatically closed after the operation returns.
public func withGUI(perform operation: (borrowing GUI) -> Void) {
  let guiRecord: StaticString = "gui"
  let guiPointer = furi_record_open(guiRecord.utf8Start)
  operation(GUI(borrowing: OpaquePointer(guiPointer)))
  furi_record_close(guiRecord.utf8Start)
}

public struct GUI: ~Copyable {
  public var pointer: OpaquePointer

  public init(borrowing pointer: OpaquePointer) {
    self.pointer = pointer
  }

  public func add(_ viewPort: borrowing ViewPort, layer: GuiLayer) {
    gui_add_view_port(pointer, viewPort.pointer, layer)
  }

  public func remove(_ viewPort: borrowing ViewPort) {
    gui_remove_view_port(pointer, viewPort.pointer)
  }
}
