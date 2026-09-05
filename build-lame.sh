#!/bin/bash
# Builds LAME as a *dynamic* xcframework for iOS.
#
# Dynamic on purpose: LAME is LGPL (version 2 or later; we distribute under 2.1), and §6(a) is
# satisfied by shipping the library so it can be replaced on its own. Static linking would put us
# on §6(b), which means distributing this app's object files — not something we're going to do.
# Nothing about AudioJoin's own source is published; what gets published alongside the app is this
# script plus the untouched LAME tarball.
#
# Output: Vendor/lame.xcframework (git-ignored — run this script to make it)
set -euo pipefail

VERSION="3.100"
# The upstream tarball's checksum, so a mirror can't hand us something else.
SHA256="ddfe36cab873794038ae2c1210557ad34857a4b6bdc515785d1da9e175b1da1e"
URL="https://downloads.sourceforge.net/project/lame/lame/${VERSION}/lame-${VERSION}.tar.gz"
MIN_IOS="17.0"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/.lame-build"
OUT="$ROOT/Vendor/lame.xcframework"

mkdir -p "$WORK"
cd "$WORK"

if [ ! -f "lame-${VERSION}.tar.gz" ]; then
	echo "==> downloading LAME ${VERSION}"
	curl -fsSL -o "lame-${VERSION}.tar.gz" "$URL"
fi
echo "${SHA256}  lame-${VERSION}.tar.gz" | shasum -a 256 -c -

# One framework per platform slice. `sdk`, `arch`, `host` and the -target triple all have to agree
# or configure silently produces a host build that links but won't run on device.
build_slice() {
	local name="$1" sdk="$2" archs="$3" target_suffix="$4"
	local sdk_path
	sdk_path="$(xcrun --sdk "$sdk" --show-sdk-path)"
	local stage="$WORK/stage-$name"
	rm -rf "$stage"
	mkdir -p "$stage"

	local slice_libs=()
	for arch in $archs; do
		local src="$WORK/src-$name-$arch"
		# Not inside $src: the tarball ships an INSTALL file, and on a case-insensitive volume a
		# prefix named "install" collides with it — `make install` then fails with "Not a directory".
		local prefix="$WORK/prefix-$name-$arch"
		rm -rf "$src" "$prefix"
		mkdir -p "$src"
		tar xzf "lame-${VERSION}.tar.gz" -C "$src" --strip-components=1

		# The only change we make to LAME's own source, and it is the same one every iOS and
		# Android build makes: 3.100's export list names `lame_init_old`, a symbol that no longer
		# exists, so the linker refuses the shared library. Dropping the line is the whole patch.
		sed -i '' '/lame_init_old/d' "$src/include/libmp3lame.sym"

		echo "==> configuring $name/$arch"
		(
			cd "$src"
			local triple="${arch}-apple-ios${MIN_IOS}${target_suffix}"
			# LAME 3.100 ships a config.sub from before arm64 existed, so `--host=arm64-...` is
			# rejected outright. The host triple only has to make configure believe it's cross
			# compiling; the -target flags below are what actually decide the code generated.
			local host="${arch}-apple-darwin"
			[ "$arch" = "arm64" ] && host="arm-apple-darwin"
			# --disable-frontend: the `lame` CLI needs a terminal library we have no use for.
			# --disable-static: we want only the shared library, per §6(a).
			./configure \
				--host="$host" \
				--prefix="$prefix" \
				--disable-static \
				--enable-shared \
				--disable-frontend \
				--disable-dependency-tracking \
				CC="$(xcrun -f clang) -target $triple -isysroot $sdk_path" \
				CFLAGS="-target $triple -isysroot $sdk_path -O2 -fPIC" \
				LDFLAGS="-target $triple -isysroot $sdk_path" \
				>"$src/configure.log" 2>&1 || { tail -25 "$src/configure.log"; exit 1; }
			make -j"$(sysctl -n hw.ncpu)" >"$src/make.log" 2>&1 || { tail -40 "$src/make.log"; exit 1; }
			make install >>"$src/make.log" 2>&1
		)
		slice_libs+=("$prefix/lib/libmp3lame.dylib")
		cp -R "$prefix/include" "$stage/include" 2>/dev/null || true
	done

	echo "==> assembling $name framework"
	local fw="$stage/lame.framework"
	mkdir -p "$fw/Headers" "$fw/Modules"
	lipo -create "${slice_libs[@]}" -output "$fw/lame"
	# Frameworks are found through @rpath at runtime; the .dylib's own id still says
	# /install/lib/libmp3lame.dylib, and dyld would go looking for exactly that.
	install_name_tool -id "@rpath/lame.framework/lame" "$fw/lame"
	cp "$stage/include/lame/lame.h" "$fw/Headers/lame.h"

	cat >"$fw/Modules/module.modulemap" <<-MODULEMAP
		framework module lame {
		    header "lame.h"
		    export *
		}
	MODULEMAP

	cat >"$fw/Info.plist" <<-PLIST
		<?xml version="1.0" encoding="UTF-8"?>
		<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
		<plist version="1.0">
		<dict>
		    <key>CFBundleDevelopmentRegion</key><string>en</string>
		    <key>CFBundleExecutable</key><string>lame</string>
		    <key>CFBundleIdentifier</key><string>org.hydrogenaudio.lame</string>
		    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
		    <key>CFBundleName</key><string>lame</string>
		    <key>CFBundlePackageType</key><string>FMWK</string>
		    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
		    <key>CFBundleVersion</key><string>${VERSION}</string>
		    <key>MinimumOSVersion</key><string>${MIN_IOS}</string>
		    <key>CFBundleSupportedPlatforms</key><array><string>${5}</string></array>
		</dict>
		</plist>
	PLIST
}

build_slice device iphoneos "arm64" "" "iPhoneOS"
build_slice simulator iphonesimulator "arm64 x86_64" "-simulator" "iPhoneSimulator"

echo "==> creating xcframework"
rm -rf "$OUT"
mkdir -p "$ROOT/Vendor"
xcodebuild -create-xcframework \
	-framework "$WORK/stage-device/lame.framework" \
	-framework "$WORK/stage-simulator/lame.framework" \
	-output "$OUT" >/dev/null

echo "built $OUT"
lipo -info "$OUT"/*/lame.framework/lame
