# Swift on Flipper Zero — A Proof of Concept

<p align="center">
  <br />
  <img src="Resources/Cover.svg" alt="A sample app running on the Flipper Zero with the Swift icon on the left and the text 'Hello, Swift!' on the right">
  <br />
  <a href="Resources/Video.mp4">Video</a>
  <br />
</p>

[Flipper Zero](https://flipperzero.one) is a multi-tool for security researchers and pentesters. It is powered by the STM32 family of microcontrollers and has a small display, a few buttons, and radios for various communication protocols. The Flipper Zero firmware includes a variety of built-in applications and also supports running custom apps, typically written in C.

With the recent developments in [Embedded Swift](https://github.com/apple/swift-evolution/blob/main/visions/embedded-swift.md), I was curious to explore the possibility of running Swift apps on the Flipper Zero. While there is extensive support for running C apps on the Flipper Zero, we are free to run any binary that can be compiled into a valid Flipper Application Package. There is already a project aimed at running [apps written in Rust on the Flipper Zero](https://github.com/flipperzero-rs/flipperzero), which served as an excellent resource for this project.

### Scope of the Project

This project intends to demonstrate that it is possible to run Swift apps on the Flipper Zero. It is *not* a reference implementation or a library that you can use to build your own apps. The goal of this project is to inspire and encourage further exploration into using Swift for embedded systems.

## Building and Running the App

### Prerequisites
- [**Swift Trunk Development Snapshot Build**]((https://www.swift.org/download/#trunk-development-main)): At the time of writing this, the Embedded mode for Swift is only available in the Trunk Development snapshot builds. You will need to install a trunk snapshot to be able to successfully build the app.
- **macOS and Xcode**: The build script is currently only supported on macOS. In theory it should be fairly easy to adapt it for Linux, but I haven't tried it. On macOS you will need to have an appropriate version of Xcode that is compatible with the Swift toolchain you are using.
- [**qFlipper**](https://flipperzero.one/update) (Optional): You may use qFlipper to copy the application to the Flipper Zero micro SD card.

### Steps

#### Step 1:

After cloning the repository you will need to fetch the Flipper Zero firmware submodule:

```
git submodule update --init --recursive
```

#### Step 2:

Run `fbt` (Flipper Build Tool) in the `flipperzero-firmware` directory to download the Flipper Zero toolchain and build the firmware:

```
cd flipperzero-firmware
./fbt
```

#### Step 3:

Flash the locally built firmware on to the Flipper Zero:

```
./fbt flash_usb
```

> [!IMPORTANT]
> This step is crucial as the submodule includes necessary modifications to the firmware for [correctly loading a Swift app](#relocations) on the Flipper Zero.

#### Step 4:

Build the Swift app:

```
cd ..
./build.sh
```

By default the build script will use the `swift-latest` toolchain installed in `/Library/Developer/Toolchains`. If you want to use a different toolchain, you can set the `TOOLCHAINS` environment variable to the identifier of the toolchain you want to use:

```
TOOLCHAINS="org.swift.59202403311a" ./build.sh
```

#### Step 5:

Copy the generated `build/Hello.fap` file to the `/apps/Examples` directory on the SD card (you can use [`qFlipper`](https://github.com/flipperdevices/qFlipper) for this) and launch the app!

## From Code to a Running App: The Journey

### Embedded Swift

Swift published its [Vision for Embedded Systems](https://github.com/apple/swift-evolution/blob/main/visions/embedded-swift.md) in October 2023 and recently also published a blog post on [Getting Started with Embedded Swift on ARM and RISC-V Microcontrollers](https://www.swift.org/blog/embedded-swift-examples/), which includes a few examples of Swift running on bare-metal ARM and RISC-V microcontrollers. Since the Flipper Zero is powered by an STM32 microcontroller, which is based on the ARM Cortex-M, it should be possible to run Swift in the Embedded mode on the Flipper Zero.

At the time of writing, Embedded Swift is still under development and only available in [Trunk Development snapshot builds](https://www.swift.org/download/#trunk-development-main). The Embedded Swift mode can be enabled by passing the `-enable-experimental-feature Embedded` flag to `swiftc`.

### Flipper Application Package

A [Flipper Application Package (.fap)](https://developer.flipper.net/flipperzero/doxygen/apps_on_sd_card.html) is a binary file format for Flipper Zero applications. It is an [ELF binary](https://en.wikipedia.org/wiki/Executable_and_Linkable_Format) with additional metadata. Specifically, it includes a `.fapmeta` section with information about the app, such as its name, icon name, and version. The `.fap` file is loaded and executed by the Flipper Zero firmware.

### Generating the Binary

To generate a binary that can be used by the Flipper Zero, we need to tell the compiler the appropriate instruction set architecture and the environment we are targeting. We can do this by passing the desired target triple to `swiftc` using the `-target` flag. In our case, we need the `armv7-none-none-eabi` target triple, which is one of the supported triples for Embedded Swift. It generates an ARMv7 ELF object file. For the Flipper Zero we specifically need to target the [Thumb instruction set architecture](https://developer.arm.com/Architectures/T32%20Instruction%20Set%20Architecture), which we can do by additionally passing the `-mthumb` flag to `clang`.

```sh
SWIFT_FLAGS+=" -target armv7-none-none-eabi -Xcc -mthumb"
```

Now we can compile a Swift source file using `swiftc`:

```sh
swiftc $SWIFT_FLAGS Hello.swift -o Hello.o
```

At the time of writing, the Swift trunk development snapshot builds do not seem to include standard libraries for the `armv7-none-none-eabi` target triple. This means that `swiftc` fails at link time when compiling for that target. [This might be an issue with the contents of the Swift toolchain](https://x.com/harlanhaskins/status/1783197237897748571). For now, we can skip the linking step by passing the `-emit-object` (or `-c`) flag to `swiftc`. We can also pass the `-nostdlib` flag to the linker to prevent it from linking the standard libraries. We'll need to link the standard libraries ourselves once we start using symbols provided by them.

```sh
SWIFT_FLAGS+=" -emit-object"
LDFLAGS+=" -nostdlib"
```

To generate a valid Flipper Application Package (`.fap`) binary, we also need to add the `.fapmeta` section to the object file containing the application manifest metadata. The manifest is represented as a C struct in the Flipper Zero firmware source code.

We should be able to directly initialize this C struct from Swift, but for this project I decided to define an equivalent struct in Swift and carefully match its layout. While that was fun to experiment with, I would suggest directly using the C struct instead, as that takes care of the memory layout for you.

Swift has experimental support for placing global constants in custom ELF sections using the `@_section` attribute under the `SymbolLinkageMarkers` experimental feature. This allows us to declare the application manifest metadata instance and place it in the correct section from right within our Swift code.

```swift
@_used
@_section(".fapmeta")
let applicationManifest = ApplicationManifestV1(
  ...
)
```

Note that we need the `@_used` attribute to ensure that the `applicationManifest` is not optimized away by the compiler.

We also need to define an entry point to the application, which is the function that gets called when our app is launched by the Flipper Zero firmware. We can do that by declaring a function with the `@_cdecl` attribute to indicate that we want to use the C calling convention. This function is expected to take a void pointer as an argument.

```swift
@_cdecl("app_entry")
public func entry(pointer: UnsafeMutableRawPointer?) -> UInt32 {
  ...
}
```

We can then pass in the C name of the function with the `--entry` (or `-e`) flag to the linker.

```sh
LDFLAGS+=" -Wl,-e,app_entry"
```

You can now recompile the Swift file with the latest changes. The linker is then run as a separate step using the following command:

```sh
clang $LD_FLAGS Hello.o -o Hello.fap
```

Now we have an executable that can be launched as an app on the Flipper Zero. You can copy this executable to the `/apps/Examples` directory on the SD card using `qFlipper`.

However, when you launch the app, you will encounter the following error:

```
Update Firmware to use with this Application (MissingImports)
```

### Reading the Logs

We will need the logs to debug this issue further. I am using the [WiFi Devboard for Flipper Zero](https://shop.flipperzero.one/products/wifi-devboard) with the [Black Magic Probe](https://github.com/blackmagic-debug/blackmagic) firmware to read Flipper Zero logs via UART. You can find the instructions here: [Reading logs via the Dev Board](https://docs.flipper.net/development/hardware/wifi-developer-board/reading-logs).

Once you have it set up with the log level on the Flipper Zero set to "Debug", you can launch the app again. You will see the following messages when the app is being loaded:

```
13843 [I][Loader] Loading /ext/apps/Examples/Hello.fap
13960 [E][Elf]   Undefined relocation 3
14129 [E][Elf]   Undefined relocation 3
14148 [E][Elf]   Undefined relocation 3
14153 [E][Elf]   No symbol address of __stack_chk_fail
14158 [E][Elf]   No symbol address of __stack_chk_guard
14160 [E][Elf]   Undefined relocation 3
14163 [E][Elf]   No symbol address of __stack_chk_guard
14167 [E][Elf]   Undefined relocation 3
14180 [E][Elf]   Undefined relocation 3
14208 [E][Elf]   Undefined relocation 3
14225 [E][Elf]   No symbol address of posix_memalign
14227 [E][Elf]   No symbol address of posix_memalign
14230 [E][Elf]   No symbol address of posix_memalign
14297 [E][Elf]   Undefined relocation 3
14332 [E][Elf] Error relocating section '.text'
14391 [I][Elf] Total size of loaded sections: 10982
14394 [E][Loader] Status [3]: Load failed, /ext/apps/Examples/Hello.fap: Update Firmware to use with this Application (MissingImports)
```

The error message `No symbol address of __stack_chk_guard` indicates that the Flipper Zero firmware is unable to resolve the symbol `__stack_chk_guard`. This symbol, along with `__stack_chk_fail` is used by Swift for stack protection. We can disable stack protectors by passing the `-Xfrontend -disable-stack-protector` flag to `swiftc`. This is helpfully documented in the [Embedded Swift User Manual](https://github.com/apple/swift/blob/main/docs/EmbeddedSwift/UserManual.md).

`posix_memalign` is required for dynamic memory allocations, which we can also disable for now by passing the `-no-allocations` flag to `swiftc`.

```sh
SWIFT_FLAGS+=" -Xfrontend -disable-stack-protector -no-allocations"
```

After building and installing the app with the updated flags, we can launch it again. This time we see that only one kind of error is remaining:

```
13885 [I][Loader] Loading /ext/apps/Examples/Hello.fap
13997 [E][Elf]   Undefined relocation 3
14032 [E][Elf]   Undefined relocation 3
14050 [E][Elf]   Undefined relocation 3
14057 [E][Elf]   Undefined relocation 3
14061 [E][Elf]   Undefined relocation 3
14070 [E][Elf]   Undefined relocation 3
14075 [E][Elf]   Undefined relocation 3
14216 [E][Elf]   Undefined relocation 3
14221 [E][Elf]   Undefined relocation 3
14226 [E][Elf]   Undefined relocation 3
14268 [E][Elf]   Undefined relocation 3
14304 [E][Elf] Error relocating section '.text'
14361 [I][Elf] Total size of loaded sections: 10826
14364 [E][Loader] Status [3]: Load failed, /ext/apps/Examples/Hello.fap: Update Firmware to use with this Application (MissingImports)
```

The error message `Undefined relocation 3` indicates that the Flipper Zero firmware is unable to resolve a relocation. Diving into the Flipper Zero firmware source code, [we can see that the error is thrown in `elf_file.c`](https://github.com/flipperdevices/flipperzero-firmware/blob/890c9e87ceac86dc3d70dd3f09657483b1c4209b/lib/flipper_application/elf/elf_file.c#L348) when loading the application. The firmware does not support resolving `R_ARM_REL32` relocations (which corresponds to the raw value of 3).

### Relocations

Relocation entries are records that indicate that the value of a symbol needs to be adjusted at runtime. When the executable is loaded into memory, the loader "resolves the relocations" by updating the symbol values with the actual addresses in memory, as specified by the relocation entries.

`R_ARM_REL32` is one such type of a relocation entry. This type of relocation entry is generated by `swiftc` in a few instances when compiling for the `armv7-none-none-eabi` target triple. While there may be ways to influence the type of relocation entries that are generated by `swiftc`, I decided to add support for the `R_ARM_REL32` relocation to the Flipper Zero firmware instead.

Upon examining the [`elf_relocate_symbol` function in `elf_file.c`](https://github.com/flipperdevices/flipperzero-firmware/blob/890c9e87ceac86dc3d70dd3f09657483b1c4209b/lib/flipper_application/elf/elf_file.c#L325) from the Flipper Zero firmware source code, we find that it only supports a few types of relocations (including `R_ARM_ABS32`) but `R_ARM_REL32` is not one of them. After a quick read through the "Relocation types" section of the [ARM ELF Specification](https://developer.arm.com/documentation/espc0003/1-0/?lang=en), I saw that the `R_ARM_REL32` relocation modifies the 32-bit word at the address being relocated, just like `R_ARM_ABS32`, but the value is resolved using the following formula:

```
S - P + A
```

where `S` is the value of the symbol, `P` is the address of the place being relocated, and `A` is the addend (value extracted from the storage unit being relocated, in this case).

We can support this relocation type fairly easily by adding an additional case for `R_ARM_REL32` to the `elf_relocate_symbol` function, implemented as follows:

```c
case R_ARM_REL32:
  *((uint32_t*)relAddr) += symAddr - relAddr;
  break;
```

*I have created a [PR with this change](https://github.com/flipperdevices/flipperzero-firmware/pull/3631) on the Flipper Zero firmware repository. Hopefully it can be integrated into the firmware, allowing us to run Swift apps on the Flipper Zero without any additional modifications.*

After building the updated firmware and flashing it to the Flipper Zero, we can try launching the app again. This time we are greeted to a successfully running app! We haven't used any of the Flipper Zero APIs yet, so we can't really display anything, but we should be able to log messages. Let's try putting some text on the screen.

### Flipper Zero APIs

The Flipper Zero firmware provides a set of APIs that can be used to conveniently interact with the hardware, like putting text on the display, reading button presses, etc. To use those APIs from Swift, we can provide the relevant C header paths to the `swiftc` invocation using the `-I` flag:

```sh
SWIFT_FLAGS+="\
  -I $FLIPPER_REPOROOT/applications/services \
  -I $FLIPPER_REPOROOT/targets/furi_hal_include \
  -I $FLIPPER_REPOROOT/targets/f18/furi_hal \
  -I $FLIPPER_REPOROOT/targets/f7/furi_hal \
  -I $FLIPPER_REPOROOT/targets/f7/inc \
  -I $FLIPPER_REPOROOT/furi \
  -I $FLIPPER_REPOROOT/lib/mlib \
  -I $FLIPPER_REPOROOT/lib/cmsis_core \
  -I $FLIPPER_REPOROOT/lib/stm32wb_hal/Inc \
  -I $FLIPPER_REPOROOT/lib/stm32wb_cmsis/Include \
  -I $FLIPPER_TOOLCHAIN/arm-none-eabi/include"
```

Then we can either use a bridging header to import the relevant C headers ([as seen in the swift-embedded-examples repository](https://github.com/apple/swift-embedded-examples/blob/main/nrfx-blink-sdk/BridgingHeader.h)), or we can define a clang module ([as seen in the swift-playdate-examples repository](https://github.com/apple/swift-playdate-examples/blob/main/Sources/CPlaydate/include/module.modulemap)). I decided to go with the latter approach.

For convenience, we can create a new header file with all the relevant header imports:

```c
// CFlipperApplication.h

#include <gui/gui.h>
#include <gui/icon_i.h>
#include <furi.h>
#include <furi_hal_memory.h>
#include <furi_hal_random.h>
```

Then we can define a module map file:

```
module CFlipperApplication [system] {
  umbrella header "CFlipperApplication.h"
  export *
}
```

Note the `system` attribute in the module declaration, which tells the compiler to consider the headers as system headers and therefore suppress all warnings generated from them.

Some of the imported headers also require us to define preprocessor macros for the exact type of the microcontroller used by the Flipper Zero. We can do that using the `-D` flag:

```sh
SWIFT_FLAGS+="\
  -Xcc -DSTM32WB55xx \
  -Xcc -DDSTM32WB"
```

We also need to add the module to the import search paths:

```sh
SWIFT_FLAGS+=" -I $SRCROOT/CFlipperApplication/include"
```

Now we are able to use the Flipper Zero APIs from Swift. As an example, we should be able to put text on the display using the following code:

```swift
import CFlipperApplication

let appDrawCallback: @convention(c) (OpaquePointer?, UnsafeMutableRawPointer?) -> Void = { canvas, _ in
  canvas_clear(canvas)
  canvas_set_font(canvas, FontPrimary)
  let message: StaticString = "Hello, Swift!"
  canvas_draw_str_aligned(canvas, 8, 8, AlignLeft, AlignTop, message.utf8Start)
}

@_cdecl("entry")
public func entry(pointer: UnsafeMutableRawPointer?) -> UInt32 {
  let viewPort = view_port_alloc()
  view_port_draw_callback_set(viewPort, appDrawCallback, nil)

  let GUI_RECORD: StaticString = "gui"
  let gui = furi_record_open(GUI_RECORD.utf8Start)
  gui_add_view_port(OpaquePointer(gui), viewPort, GuiLayerFullscreen)
  view_port_update(viewPort);

  while true {
    // Wait forever
  }

  view_port_enabled_set(viewPort, false)
  gui_remove_view_port(OpaquePointer(gui), viewPort)
  view_port_free(viewPort)
  furi_record_close(GUI_RECORD.utf8Start)
  return 0
}
```

When you launch the app, you should see "Hello, Swift!" on the display!

### ABI Compatibility

At this point I had a Swift app that displayed static text on the screen. As I added more features to the app, I started encountering some unexpected behaviors and even unexplainable crashes. After some debugging, I noticed that the members of one of the struct instances had wildly different values from what I expected. This pointed towards mismatched memory layouts and I realized that there are a few additional challenges that I needed to address.

Unlike the examples in the [Getting Started with Embedded Swift on ARM and RISC-V Microcontrollers](https://www.swift.org/blog/embedded-swift-examples/) blog post, which run on bare-metal, in our case the Flipper Zero firmware loads and runs our `.fap` binary. We therefore need to ensure that the binary we generate expects the same memory layout for objects vended by the system and the uses the same calling conventions. This is something that Rauhul Varma also had to deal with while [building games for the Playdate in Swift](https://www.swift.org/blog/byte-sized-swift-tiny-games-playdate/#running-on-the-hardware-again).

I ended up compiling a C application for the Flipper Zero on the side, and then I was able to copy over the relevant flags that were passed to the `arm-none-eabi-gcc` invocation by the Flipper Build Tool (fbt). This included flags such as `-fshort-enums`, to ensure that we match the memory layout of enums on the Flipper Zero and `-mfloat-abi=hard` to use the hardware floating point unit.

```sh
SWIFT_FLAGS+="\
  -Xfrontend -experimental-platform-c-calling-convention=arm_aapcs_vfp \
  -Xcc -fshort-enums \
  -Xcc -mcpu=cortex-m4 \
  -Xcc -mfloat-abi=hard \
  -Xcc -mfpu=fpv4-sp-d16"
```

Now the Swift app was running stably on the Flipper Zero. We are quite limited in the set of Swift standard library types that we can use because we had disabled dynamic memory allocations. I wanted to see if I could get dynamic allocations working.

### Patching Missing Symbols

To enable dynamic memory allocations Swift relies on the `posix_memalign` function. This is again helpfully documented in the [Embedded Swift User Manual](https://github.com/apple/swift/blob/main/docs/EmbeddedSwift/UserManual.md). The Flipper Zero firmware does not provide an implementation for it, so we need to provide our own.

The Flipper Zero API does include an `aligned_malloc` function, which ensures aligned memory allocations. However, it requires you to use the `aligned_free` function to free the memory. Memory allocated using `posix_memalign` is expected to be freed using the `free` function, which means that we can't directly use `aligned_malloc` to implement `posix_memalign`.

We could write our own implementation for `posix_memalign` which over-allocates and offsets the pointer, but we would run into a similar problem with `free`, because `free` expects to receive a pointer that was returned by `malloc`. While not ideal, I ended up directly calling `malloc` without constraining the alignment. This is not a correct implementation but seems to work for the purposes of this project. Ideally, the Flipper Zero firmware could be extended to provide a correct implementation for `posix_memalign`.

To use dictionaries and sets in Swift, we also need to provide an implementation for `arc4random_buf`, which can be done by forwarding the call to `furi_hal_random_fill_buf`.

You can find the implementation of these functions in [`Sources/CFlipperApplication/patch_symbols.c`](Sources/CFlipperApplication/patch_symbols.c). This file is compiled separately and linked to the main app's object file.

```sh
$LD_EXEC ${=LD_FLAGS} \
  $BUILDROOT/Hello.o \
  $BUILDROOT/patch_symbols.o \
  -o $BUILDROOT/Hello.fap
```

Finally we are at a point where we can use most of the Swift features! (Except Strings, which are not available in the Embedded Swift mode at the time of writing)

### The Compiler Runtime Library

However, there's one last thing that we need to fix. While experimenting with the app, I started hitting the following loader error whenever I included code that tried to divide an integer by `6`. I was able to divide by `4` or `8` just fine, but not by `6`.

```
No symbol address of __aeabi_uldivmod
```

Looking into `__aeabi_uldivmod`, I found that it is a helper function used by the compiler to perform division and modulo operations on unsigned long integers. It is usually provided by the compiler's runtime library, like `libgcc` or Clang's `compiler-rt`. Since the Swift trunk development snapshot builds do not include standard libraries for the `armv7-none-none-eabi` target triple, I decided to link the `libgcc` that comes as part of the `arm-none-eabi-gcc` cross compiler included with the Flipper Zero toolchain. It also provides the `__aeabi_uldivmod` symbol that we need. This approach likely has its own set of challenges, but it seems to work for now and requires much less effort than compiling my own runtime library.

```sh
LDFLAGS+=" -L$FLIPPER_TOOLCHAIN/lib/gcc/arm-none-eabi/12.3.1/thumb/v7e-m+fp/hard -lgcc"
```

After linking `libgcc` and running the app for one last time, I was able to divide by `6` without any issues. We are now successfully able to run a Swift app on the Flipper Zero with most of the Swift features available to us!

### Hello, Swift!

For the example app in this project, I decided to display the Swift logo alongside the text "Hello, Swift!". The text bounces vertically on the screen. You can move the text around using the arrow buttons. You can also display the amount of available memory by pressing the center button.

Icons used by a Flipper Zero app are embedded into the `.fap` binary. The Flipper Build Tool (`fbt`) can generate a C file with byte arrays containing the icon data. Normally that C file is compiled and statically linked with the main application into a single `.fap` file. I instead used this feature to generate a byte array of the Swift logo and then manually copied it over to a Swift source file. Ideally, we should be able to write a code generator to directly generate a Swift source file with the images, but that is beyond the scope of this project.

To enhance the development experience I also wrote Swift wrappers for some commonly used C APIs that are provided by the Flipper Zero. This helped me write code that felt more Swift-y and less C-like. :P

You can find the source code for the example app in [`Sources/Hello`](Sources/Hello).

## Final Thoughts

As things stand today, there are a few constraints that heavily limit the usability and experience of programming in Swift for the Flipper Zero:

- No support for Strings: This is a big limitation, as Strings are a fundamental part of Swift. I frequently ran into this when attempting to log specific pieces of data from Swift. Though, there is some hope as [support for Strings is currently WIP](https://github.com/apple/swift/blob/main/docs/EmbeddedSwift/EmbeddedSwiftStatus.md).
- No debugger support: This might be an interesting challenge in itself.
- The Flipper C APIs are not Swift-friendly: While you can work with them directly, it's much more cumbersome than using them from C. You are almost forced to write a wrapper to have a good experience.

Despite these limitations, getting Swift to run on the Flipper Zero was a fun project. It highlights the potential of using Swift for embedded systems, especially with the ongoing development work.

## Helpful Resources

- [Flipper Zero Firmware](https://github.com/flipperdevices/flipperzero-firmware)
- [Embedded Swift Example Projects](https://github.com/apple/swift-embedded-examples)
- [Embedded Swift User Manual](https://github.com/apple/swift/blob/main/docs/EmbeddedSwift/UserManual.md)
- [Rust for Flipper Zero](https://github.com/flipperzero-rs/flipperzero)
- [Byte-sized Swift: Building Tiny Games for the Playdate](https://www.swift.org/blog/byte-sized-swift-tiny-games-playdate/)
- [ARM ELF Specification](https://developer.arm.com/documentation/espc0003/1-0/?lang=en)
- [Swift Programming Language](https://github.com/apple/swift)
- [The LLVM Compiler Infrastructure](https://github.com/llvm/llvm-project)
