# bpy-linux-aarch64

[Blender](https://www.blender.org) as a Python module (`bpy`) for **Linux on ARM64 / aarch64**, with Cycles on NVIDIA GPUs (CUDA and OptiX).

Blender publishes `bpy` wheels for Linux x86_64, macOS arm64 and Windows, but not for Linux ARM. On a DGX Spark, a Grace Hopper node or a Jetson, `pip install bpy` or `uv sync` stops with:

```text
error: Distribution `bpy==5.2.2` can't be installed because it doesn't have a source distribution or wheel for the current platform
```

This repo builds the missing wheel the way Blender builds its own. It changes no Blender source.

## Install

Download the wheel from [Releases](../../releases), then:

```bash
pip install bpy-5.2.2-cp313-cp313-manylinux_2_28_aarch64.whl
```

In a uv project that depends on `bpy`:

```bash
uv sync --no-install-package bpy
uv pip install bpy-5.2.2-cp313-cp313-manylinux_2_28_aarch64.whl
uv run --no-sync python -c "import bpy; print(bpy.app.version_string)"
```

Requires Python 3.13 and glibc 2.28 or newer (Ubuntu 20.04+, Debian 11+, RHEL 8+). Cycles finds the GPU through the driver; no CUDA toolkit is needed at runtime.

## How it's built

Every step follows Blender's buildbot ([`blender-devops`](https://projects.blender.org/infrastructure/blender-devops), `buildbot/worker/blender/compile.py` and `pack.py`), and every version comes from the Blender tag being built. Four steps differ, because ARM Linux forces them:

| Step | Blender's buildbot | Here |
|---|---|---|
| Build environment | Rocky 8, from `linux_rocky8_setup.sh` | Same, at the tag being built |
| CUDA, OptiX versions | The tag's `build_files/config/pipeline_config.yaml` | Same |
| CMake presets | `blender_linux.cmake`, `bpy_module.cmake`, `WITH_INSTALL_PORTABLE`, `WITH_STRICT_BUILD_OPTIONS` | Same |
| Wheel | `make_bpy_wheel.py <install> --build-dir <build>` | Same |
| **Libraries** | `lib/linux_x64`, pinned per tag as a submodule | `lib-linux_arm64`, which Blender maintains but doesn't pin: the head of the series' release branch, recorded in each release |
| **OptiX** | NVIDIA's SDK installer | Headers from [NVIDIA/optix-dev](https://github.com/NVIDIA/optix-dev); there is no ARM Linux installer, and Cycles needs only the headers |
| **GPU backends** | CUDA, OptiX, HIP, oneAPI | CUDA and OptiX: AMD and Intel ship no ARM Linux toolchains |
| **CUDA kernels** | x86 desktop GPUs | NVIDIA GPUs that sit next to an ARM CPU: Jetson Orin (`sm_87`), Grace Hopper (`sm_90`), Grace Blackwell (`sm_100`), RTX Blackwell (`sm_120`), DGX Spark (`sm_121`), plus PTX for newer ones |

## Build it yourself

On any aarch64 Linux host with Docker (no GPU needed):

```bash
./build.sh            # the tag in versions.env
./build.sh v5.2.4     # any other Blender tag
```

The wheel lands in `work/dist/`, next to a `.buildinfo` file listing every commit and version that went in. `work/` keeps sources and object files, so a rebuild is incremental.

CI runs the same script on GitHub's `ubuntu-24.04-arm` runners: run the **build** workflow with a list of tags and each gets its own release.

## Licence

GPL-2.0-or-later, as Blender. The wheels are Blender, built unmodified from the tag each release names. Blender is a trademark of the Blender Foundation; this project is not affiliated with it.
