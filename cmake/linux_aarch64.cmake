# Loaded after the presets Blender's buildbot uses (blender_linux, bpy_module).
# Its release preset turns on every GPU backend; AMD and Intel ship no ARM
# Linux toolchains, and WITH_STRICT_BUILD_OPTIONS fails on a missing one.

set(WITH_CYCLES_DEVICE_HIP       OFF CACHE BOOL "" FORCE)
set(WITH_CYCLES_DEVICE_HIPRT     OFF CACHE BOOL "" FORCE)
set(WITH_CYCLES_HIP_BINARIES     OFF CACHE BOOL "" FORCE)
set(WITH_CYCLES_DEVICE_ONEAPI    OFF CACHE BOOL "" FORCE)
set(WITH_CYCLES_ONEAPI_BINARIES  OFF CACHE BOOL "" FORCE)
