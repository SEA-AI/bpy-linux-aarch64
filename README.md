# bpy-linux-aarch64

[Blender](https://www.blender.org) as a Python module (`bpy`) for **Linux on ARM64 / aarch64**, with Cycles on NVIDIA GPUs (CUDA and OptiX).

Blender publishes `bpy` wheels for Linux x86_64, macOS arm64 and Windows, but not for Linux ARM. On a DGX Spark, a Grace Hopper node or a Jetson, `pip install bpy` or `uv sync` stops with:

```text
error: Distribution `bpy==5.2.2` can't be installed because it doesn't have a source distribution or wheel for the current platform
```

This repo builds the missing wheel the way Blender builds its own. It changes no Blender source.

## Install

The wheels are on [Releases](../../releases) and on a PEP 503 index at `https://sea-ai.github.io/bpy-linux-aarch64/simple/`.

```bash
pip install bpy --extra-index-url https://sea-ai.github.io/bpy-linux-aarch64/simple/
```

In a uv project, take only `bpy` on Linux aarch64 from the index and everything else from PyPI:

```toml
[tool.uv.sources]
bpy = [
    { index = "bpy-aarch64", marker = "sys_platform == 'linux' and platform_machine == 'aarch64'" },
]

[[tool.uv.index]]
name = "bpy-aarch64"
url = "https://sea-ai.github.io/bpy-linux-aarch64/simple/"
explicit = true
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

## Publish

A release holds the wheel and its `METADATA` as `<wheel>.metadata` (PEP 658), so a resolver reads the dependencies without downloading the wheel. [ghr-pypi](https://ghr-pypi.readthedocs.io/) builds the index from the releases and [ghp-import](https://github.com/c-w/ghp-import) pushes it to the `gh-pages` branch, which GitHub Pages serves:

```bash
tag=v5.2.2 wheel=work/dist/bpy-5.2.2-cp313-cp313-manylinux_2_28_aarch64.whl
unzip -p "$wheel" "bpy-${tag#v}.dist-info/METADATA" > "$wheel.metadata"
gh release create "$tag" "$wheel" "$wheel.metadata" --title "bpy ${tag#v}" --notes-file notes.md
GHR_PYPI_TOKEN=$(gh auth token) uvx ghr-pypi index SEA-AI/bpy-linux-aarch64 --out _site
uvx ghp-import --no-jekyll --push _site
```

The notes list the `.buildinfo` commits and versions, as in [v5.2.2](../../releases/tag/v5.2.2).

## Licence

GPL-2.0-or-later, as Blender. The wheels are Blender, built unmodified from the tag each release names. Blender is a trademark of the Blender Foundation; this project is not affiliated with it.
