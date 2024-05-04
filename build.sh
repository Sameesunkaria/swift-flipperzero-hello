#!/bin/zsh

set -e

REPOROOT=$(git rev-parse --show-toplevel)
SRCROOT=$REPOROOT/Sources
BUILDROOT=$REPOROOT/build
ARCH_TYPE=$(uname -m)
FLIPPER_REPOROOT=$REPOROOT/flipperzero-firmware
FLIPPER_TOOLCHAIN=$FLIPPER_REPOROOT/toolchain/$ARCH_TYPE-darwin

# At the time of writing this, a Swift nightly toolchain must be used.
# You can download the latest toolchain from https://swift.org/download/.
# This project is known to work with swift-DEVELOPMENT-SNAPSHOT-2024-04-23-a.
TOOLCHAINS=${TOOLCHAINS:-`plutil -extract CFBundleIdentifier raw '/Library/Developer/Toolchains/swift-latest.xctoolchain/Info.plist'`}
TARGET='armv7-none-none-eabi'

# The following flags are a best-attempt at generating an ABI-compatible
# binary with the Flipper firmware. The C flags are are copied over from
# the arm-none-eabi-gcc invocation by fbt (Flipper Build Tool).
# The include paths are added based on the requirements of this example.
# They may not cover the entire surface of the APIs provided to a flipper
# application.
# Stack protectors depend on symbols that are not provided by the Flipper
# firmware (e.g. __stack_chk_fail) and are therefore disabled.
SWIFT_EXEC=${SWIFT_EXEC:-`TOOLCHAINS=$TOOLCHAINS xcrun -f swiftc`}
SWIFT_FLAGS="\
  -Osize \
  -target $TARGET \
  -wmo \
  -enable-experimental-feature Embedded \
  -enable-experimental-feature SymbolLinkageMarkers \
  -enable-experimental-feature TypedThrows \
  -Xfrontend -disable-stack-protector \
  -Xfrontend -experimental-platform-c-calling-convention=arm_aapcs_vfp \
  -Xcc -DSTM32WB55xx \
  -Xcc -DDSTM32WB \
  -Xcc -mthumb \
  -Xcc -fshort-enums \
  -Xcc -mcpu=cortex-m4 \
  -Xcc -mfloat-abi=hard \
  -Xcc -mfpu=fpv4-sp-d16 \
  -I $SRCROOT/CFlipperApplication/include \
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
  -I $FLIPPER_TOOLCHAIN/arm-none-eabi/include \
  -I $BUILDROOT \
  "

CLANG_EXEC=${CLANG_EXEC:-`TOOLCHAINS=$TOOLCHAINS xcrun -f clang`}
CLANG_FLAGS="\
  -target $TARGET -Oz \
  -DSTM32WB55xx \
  -DDSTM32WB \
  -mthumb \
  -fshort-enums \
  -mcpu=cortex-m4 \
  -mfloat-abi=hard \
  -mfpu=fpv4-sp-d16 \
  -I$FLIPPER_REPOROOT/targets/furi_hal_include \
  -I$FLIPPER_REPOROOT/targets/f7/furi_hal \
  -I$FLIPPER_REPOROOT/targets/f7/inc \
  -I$FLIPPER_REPOROOT/furi \
  -I$FLIPPER_REPOROOT/lib/mlib \
  -I$FLIPPER_REPOROOT/lib/cmsis_core \
  -I$FLIPPER_REPOROOT/lib/stm32wb_hal/Inc \
  -I$FLIPPER_REPOROOT/lib/stm32wb_cmsis/Include
  -I$FLIPPER_TOOLCHAIN/arm-none-eabi/include \
  "

# The swift nightly toolchain does not include standard libraries for the
# armv7-none-none-eabi target, so we use the libraries provided by
# arm-none-eabi-gcc, which is part of the Flipper toolchain. In particular,
# we use libgcc in place for Clang's compiler-rt (here be dragons). We also
# link against libm, which provides the ceil function used when operating on
# sets or dictionaries in Swift.
# We require the compiler runtime library (libgcc) for operations, such as
# integer division, that may not be natively supported by the cpu.
LD_EXEC=${LD_EXEC:-$CLANG_EXEC}
LD_FLAGS="\
  -target $TARGET \
  -nostdlib \
  -static \
  -Wl,-e,entry \
  -Wl,-r \
  -L$FLIPPER_TOOLCHAIN/lib/gcc/arm-none-eabi/12.3.1/thumb/v7e-m+fp/hard \
  -lgcc \
  -L$FLIPPER_TOOLCHAIN/arm-none-eabi/lib/thumb/v7e-m+fp/hard \
  -lm \
  "

mkdir -p $BUILDROOT

$CLANG_EXEC ${=CLANG_FLAGS} \
  -c $SRCROOT/CFlipperApplication/patch_symbols.c \
  -o $BUILDROOT/patch_symbols.o

$SWIFT_EXEC ${=SWIFT_FLAGS} \
  $SRCROOT/FlipperApplication/*.swift \
  -module-name "FlipperApplication" \
  -emit-module \
  -emit-module-path $BUILDROOT/FlipperApplication.swiftmodule

$SWIFT_EXEC ${=SWIFT_FLAGS} \
  $SRCROOT/Hello/*.swift \
  -emit-object \
  -o $BUILDROOT/Hello.o

$LD_EXEC ${=LD_FLAGS} $BUILDROOT/Hello.o $BUILDROOT/patch_symbols.o \
  -o $BUILDROOT/Hello.fap
