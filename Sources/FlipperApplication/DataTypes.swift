import CFlipperApplication

public struct Point: Hashable {
  public var x: Int32
  public var y: Int32

  public init(x: Int32, y: Int32) {
    self.x = x
    self.y = y
  }
}

public typealias Ticks = UInt32

public enum Timeout: RawRepresentable {
  case waitForever
  case ticks(Ticks)

  public init(rawValue: Ticks) {
    if rawValue == FuriWaitForever.rawValue {
      self = .waitForever
    } else {
      self = .ticks(rawValue)
    }
  }

  public var rawValue: Ticks {
    switch self {
    case .waitForever:
      return FuriWaitForever.rawValue
    case .ticks(let ticks):
      return ticks
    }
  }
}

public struct FuriError: Error {
  public var code: FuriStatus

  public init(code: FuriStatus) {
    self.code = code
  }
}
