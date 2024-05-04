import CFlipperApplication

public enum Logger {
  public static let defaultTag: StaticString = "FlipperApplicaiton.Logger"

  public static func logError(tag: StaticString = Self.defaultTag, _ message: StaticString) {
    furi_log_non_variadic(FuriLogLevelError, tag.utf8Start, message.utf8Start)
  }

  public static func logWarn(tag: StaticString = Self.defaultTag, _ message: StaticString) {
    furi_log_non_variadic(FuriLogLevelWarn, tag.utf8Start, message.utf8Start)
  }

  public static func logInfo(tag: StaticString = Self.defaultTag, _ message: StaticString) {
    furi_log_non_variadic(FuriLogLevelInfo, tag.utf8Start, message.utf8Start)
  }

  public static func logDebug(tag: StaticString = Self.defaultTag, _ message: StaticString) {
    furi_log_non_variadic(FuriLogLevelDebug, tag.utf8Start, message.utf8Start)
  }

  public static func logTrace(tag: StaticString = Self.defaultTag, _ message: StaticString) {
    furi_log_non_variadic(FuriLogLevelTrace, tag.utf8Start, message.utf8Start)
  }
}
