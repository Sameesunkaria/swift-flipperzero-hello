import CFlipperApplication

public struct Canvas {
  public var pointer: OpaquePointer

  public init(borrowing pointer: OpaquePointer) {
    self.pointer = pointer
  }

  public var width: Int {
    canvas_width(pointer)
  }

  public var height: Int {
    canvas_height(pointer)
  }

  public func clear() {
    canvas_clear(pointer)
  }

  public func setFont(_ font: Font) {
    canvas_set_font(pointer, font)
  }

  public var currentFontHeight: Int {
    canvas_current_font_height(pointer)
  }

  public func drawText(_ text: StaticString, at position: Point, horizonalAlignment: Align = AlignLeft, verticalAlignment: Align = AlignBottom) {
    canvas_draw_str_aligned(pointer, position.x, position.y, AlignLeft, AlignTop, text.utf8Start)
  }

  public func drawIcon(_ icon: [UInt8], at position: Point, width: UInt16, height: UInt16) {
    icon.withUnsafeBufferPointer { iconPointer in
      let frames = [iconPointer.baseAddress]
      frames.withUnsafeBufferPointer { framesPointer in
        var icon = Icon(width: width, height: height, frame_count: 1, frame_rate: 0, frames: framesPointer.baseAddress)
        canvas_draw_icon(pointer, position.x, position.y, &icon)
      }
    }
  }

  public func drawIcon(_ icon: inout Icon, at position: Point) {
    canvas_draw_icon(pointer, position.x, position.y, &icon)
  }
}
