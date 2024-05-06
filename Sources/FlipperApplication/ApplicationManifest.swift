// Define the applicaiton manifest structure for the Flipper application.
// It is carefully crafted to match the layout of the FlipperApplicationManifest
// C struct defined in application_manifest.h. The manifest is finally placed in
// the .fapmeta section of the elf binary.
//
// While this works, it is not ideal. Using the C struct directly might have been
// a better solution but this serves as a proof of concept of generating a layout
// compatible struct and placing it in a specific section of the binary entirely
// in Swift.

@frozen
public struct ManifestBase {
  /// The magic constant for the manifest. Currently 0x52474448.
  public var manifestMagic: UInt32

  public var manifestVersion: UInt32

  /// Must match the version defined in flipperzero-firmware/targets/f7/api_symbols.csv.
  public var apiVersion: UInt32

  public var hardwareTargetID: UInt16

  public init(
    manifestMagic: UInt32,
    manifestVersion: UInt32,
    apiVersion: UInt32,
    hardwareTargetID: UInt16
  ) {
    self.manifestMagic = manifestMagic
    self.manifestVersion = manifestVersion
    self.apiVersion = apiVersion
    self.hardwareTargetID = hardwareTargetID
  }
}

public typealias CStr32 = (
  CChar, CChar, CChar, CChar,
  CChar, CChar, CChar, CChar,
  CChar, CChar, CChar, CChar,
  CChar, CChar, CChar, CChar,
  CChar, CChar, CChar, CChar,
  CChar, CChar, CChar, CChar,
  CChar, CChar, CChar, CChar,
  CChar, CChar, CChar, CChar
)

@frozen
public struct ManifestIcon {
  public var hasIcon: Bool
  public var name: CStr32

  public init(
    hasIcon: Bool,
    name: CStr32
  ) {
    self.hasIcon = hasIcon
    self.name = name
  }
}

@frozen
public struct ApplicationManifestV1 {
  public var base: ManifestBase
  public var stackSize: UInt16
  public var appVersion: UInt32
  public var name: CStr32
  public var icon: ManifestIcon

  public init(
    base: ManifestBase,
    stackSize: UInt16,
    appVersion: UInt32,
    name: CStr32,
    icon: ManifestIcon
  ) {
    self.base = base
    self.stackSize = stackSize
    self.appVersion = appVersion
    self.name = name
    self.icon = icon
  }
}
