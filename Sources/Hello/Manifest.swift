import FlipperApplication

// The app name and the icon file names are both fixed size 32 byte strings.
// Swift deos not have a fixed size string type, so we are manually writing
// out the 32 element tuples for the name and icon. The ergonomics of this
// may be improved by using a Swift macro but that is beyond the scope of this
// project.

@_used
@_section(".fapmeta")
let applicationManifest = ApplicationManifestV1(
  base: ManifestBase(
    manifestMagic: 0x52474448,
    manifestVersion: 1,
    // Version 86.0; Must match the version defined in
    // flipperzero-firmware/targets/f7/api_symbols.csv
    apiVersion: 0x00560001,
    hardwareTargetID: 7
  ),
  stackSize: 2048,
  appVersion: 1,
  // "A Swift App" in ASCII
  name: (65,32,83,119,105,102,116,32,65,112,112,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
  icon: ManifestIcon(
    hasIcon: false,
    name: (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
  )
)
