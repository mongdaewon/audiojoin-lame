#!/bin/bash
# Builds LAME as the shared libmp3lame.so AudioJoin for Android ships, one per ABI.
#
# See android/CMakeLists.txt for why it is a shared library. The source is the same verified
# tarball the iOS script uses, unpacked and compiled as is.
#
# Requires the Android NDK (r28 is what the app uses): set ANDROID_NDK_HOME, or have it under
# ~/Library/Android/sdk/ndk. Output: android/out/<abi>/libmp3lame.so (git-ignored).
set -euo pipefail

VERSION="3.100"
SHA256="ddfe36cab873794038ae2c1210557ad34857a4b6bdc515785d1da9e175b1da1e"
URL="https://downloads.sourceforge.net/project/lame/lame/${VERSION}/lame-${VERSION}.tar.gz"
ABIS=(arm64-v8a armeabi-v7a x86_64)
API=29

ROOT="$(cd "$(dirname "$0")" && pwd)"
WORK="$ROOT/.lame-android"
NDK="${ANDROID_NDK_HOME:-$(ls -d "$HOME"/Library/Android/sdk/ndk/* 2>/dev/null | sort -V | tail -1)}"
[ -d "$NDK" ] || { echo "Android NDK not found: set ANDROID_NDK_HOME"; exit 1; }

cd "$ROOT"
if [ ! -f "lame-${VERSION}.tar.gz" ]; then
	echo "==> downloading LAME ${VERSION}"
	curl -fsSL -o "lame-${VERSION}.tar.gz" "$URL"
fi
echo "${SHA256}  lame-${VERSION}.tar.gz" | shasum -a 256 -c -

rm -rf "$WORK"
mkdir -p "$WORK/src"
tar xzf "lame-${VERSION}.tar.gz" -C "$WORK/src" --strip-components=1

for abi in "${ABIS[@]}"; do
	echo "==> building $abi"
	cmake -S android -B "$WORK/build-$abi" \
		-DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" \
		-DANDROID_ABI="$abi" -DANDROID_PLATFORM="android-$API" \
		-DCMAKE_BUILD_TYPE=Release -DLAME_SRC="$WORK/src" >/dev/null
	cmake --build "$WORK/build-$abi" -j >/dev/null
	mkdir -p "android/out/$abi"
	cp "$WORK/build-$abi/libmp3lame.so" "android/out/$abi/"
done

echo "built:"
ls -la android/out/*/libmp3lame.so
