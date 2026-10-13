# audiojoin-lame

The source of the MP3 encoder that ships inside [AudioJoin](https://mongdaewon.com/apps/audiojoin/), and the script that builds it.

AudioJoin writes MP3 files with [LAME](https://lame.sourceforge.io/), because Apple does not provide an MP3 encoder on iPhone or iPad. LAME is free software, so this repository exists to make its source available to anyone who has the app — that is what the LGPL asks for.

**Nothing of AudioJoin's own source is here, and none is required to be.** The obligation covers the library, not the application.

## What's in here

| File | |
|---|---|
| `lame-3.100.tar.gz` | Upstream LAME 3.100, exactly as published by the LAME project |
| `build-lame.sh` | The script that turns it into the `lame.xcframework` the iOS app embeds |
| `build-lame-android.sh`, `android/CMakeLists.txt` | The Android build: the `libmp3lame.so` the Android app ships, one per ABI |
| `COPYING` | The license text shipped inside the tarball |

Checksum of the tarball (also checked by the script):

```
ddfe36cab873794038ae2c1210557ad34857a4b6bdc515785d1da9e175b1da1e  lame-3.100.tar.gz
```

## License

LAME is © 1998–2017 The LAME Project and is distributed under the **GNU Library General Public License, version 2, or (at your option) any later version** (`COPYING`, and the header of every source file). AudioJoin distributes it under **version 2.1** of that license: [full text](https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html).

The app links LAME as a **dynamic framework**, embedded next to the app binary rather than compiled into it. That is §6(a) of the license: the library can be replaced with a different build of LAME without needing anything else from us.

## What we changed

One line, and the script does it:

```sh
sed -i '' '/lame_init_old/d' "$src/include/libmp3lame.sym"
```

LAME 3.100's export list names `lame_init_old`, a symbol that no longer exists in the code. The linker refuses to build a shared library that promises a symbol it doesn't have, so the line has to go. Nothing else in the source is touched.

## Building it

Requires Xcode command line tools on macOS.

```sh
./build-lame.sh
```

It verifies the tarball against the checksum above (downloading it if you removed it), builds device and simulator slices, and writes `Vendor/lame.xcframework` relative to the script's parent directory. That framework is byte-for-byte what the released app embeds, up to the usual compiler nondeterminism.

### Android

Requires the Android NDK (r28) and CMake.

```sh
./build-lame-android.sh
```

It verifies the same tarball, unpacks it untouched, and writes `android/out/<abi>/libmp3lame.so` for arm64-v8a, armeabi-v7a and x86_64. The Android app ships LAME the same way: as that separate shared library, loaded next to the app's own code rather than compiled into it, so it can be replaced on its own. The Android build compiles the encoder sources directly and does not use the export list, so the one-line fix above is not needed there; the decoder glue (`mpglib_interface.c`) is left out.

## Relinking the app against a different LAME

If you want AudioJoin built against a newer or differently configured LAME, email us and we will ship an update with it.

support@mongdaewon.com
