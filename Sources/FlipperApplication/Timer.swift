import CFlipperApplication

public struct Timer: ~Copyable {
  public var pointer: UnsafeMutableRawPointer
  public var callbackPointer: UnsafeMutablePointer<() -> Void>

  public init(type: FuriTimerType, callback: @escaping () -> Void) {
    let callbackPointer = UnsafeMutablePointer<() -> Void>.allocate(capacity: 1)
    callbackPointer.pointee = callback
    self.callbackPointer = callbackPointer
    pointer = furi_timer_alloc(timerCallback, type, callbackPointer).unsafelyUnwrapped
  }

  deinit {
    furi_timer_free(pointer)
    callbackPointer.deallocate()
  }

  typealias TimerCallback = @convention(c) (UnsafeMutableRawPointer?) -> Void
  private let timerCallback: TimerCallback = { contextPointer in
    contextPointer.unsafelyUnwrapped.withMemoryRebound(to: (() -> Void).self, capacity: 1) { callbackPointer in
      callbackPointer.pointee()
    }
  }

  public func start(interval ticks: Ticks) {
    furi_timer_start(pointer, ticks)
  }

  public func restart(interval ticks: Ticks) {
    furi_timer_restart(pointer, ticks)
  }

  public func stop() {
    furi_timer_stop(pointer)
  }

  public var isRunning: Bool {
    furi_timer_is_running(pointer) != 0
  }

  public func expiredTime() -> Ticks {
    furi_timer_get_expire_time(pointer)
  }

  public static func setThreadPriority(_ priority: FuriTimerThreadPriority) {
    furi_timer_set_thread_priority(priority)
  }
}
