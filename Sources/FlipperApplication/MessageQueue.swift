import CFlipperApplication

public struct MessageQueue<T>: ~Copyable {
  public var messageQueue: OpaquePointer
  public var capacity: UInt32

  public init(capacity: UInt32) {
    self.capacity = capacity
    messageQueue = furi_message_queue_alloc(capacity, UInt32(MemoryLayout<T>.size)).unsafelyUnwrapped
  }

  deinit {
    furi_message_queue_free(messageQueue)
  }

  public func get(timeout: Timeout = .waitForever) throws(FuriError) -> T {
    let messagePointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
    defer { messagePointer.deallocate() }
    let status = furi_message_queue_get(messageQueue, messagePointer, timeout.rawValue)
    guard status == FuriStatusOk else { throw FuriError(code: status) }
    return messagePointer.pointee
  }

  public func put(_ event: T, timeout: Timeout = .waitForever) throws(FuriError) {
    let messagePointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
    defer { messagePointer.deallocate() }
    messagePointer.pointee = event
    let status = furi_message_queue_put(messageQueue, messagePointer, timeout.rawValue)
    guard status == FuriStatusOk else { throw FuriError(code: status) }
  }
}
