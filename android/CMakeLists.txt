# Builds LAME 3.100 as the shared library AudioJoin for Android ships: libmp3lame.so.
#
# Shared on purpose, the same reason as the iOS framework: LGPL §6(a) is met by a library that can be
# replaced on its own. The app's JNI glue links to this .so dynamically; nothing of LAME is compiled
# into the app's own code.
#
# LAME_SRC is the unpacked upstream tarball. Nothing in it is edited: the Android build compiles
# libmp3lame/*.c directly and never reads libmp3lame.sym, so the iOS script's one-line fix to that
# export list isn't needed here. The decoder glue (mpglib_interface.c) is left out — encode only.
cmake_minimum_required(VERSION 3.22.1)
project(mp3lame C)

file(GLOB LAME_SOURCES ${LAME_SRC}/libmp3lame/*.c)
list(REMOVE_ITEM LAME_SOURCES ${LAME_SRC}/libmp3lame/mpglib_interface.c)
add_library(mp3lame SHARED ${LAME_SOURCES})
target_include_directories(mp3lame PUBLIC ${LAME_SRC}/include PRIVATE ${LAME_SRC}/libmp3lame)
# What configure would have found on any Android libc.
target_compile_definitions(mp3lame PRIVATE STDC_HEADERS HAVE_STDINT_H HAVE_ERRNO_H HAVE_FCNTL_H HAVE_LIMITS_H
    "ieee754_float32_t=float")
target_compile_options(mp3lame PRIVATE -O2 -w)
target_link_libraries(mp3lame m)
