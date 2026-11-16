# bpy for Linux aarch64

[![Release](https://img.shields.io/github/v/release/SEA-AI/bpy-linux-aarch64?label=bpy)](https://github.com/SEA-AI/bpy-linux-aarch64/releases/latest)
![Python 3.13](https://img.shields.io/badge/python-3.13-blue)
![Platform](https://img.shields.io/badge/platform-linux%20aarch64-lightgrey)
[![Licence](https://img.shields.io/badge/licence-GPL--2.0--or--later-green)](LICENSE)

[Blender](https://www.blender.org) as a Python module, `bpy`, for Linux on ARM64, with Cycles on NVIDIA GPUs.

Blender publishes `bpy` wheels for Linux x86_64, macOS and Windows, not for Linux aarch64. This repo builds that wheel from Blender's own release tag, unmodified, the way Blender's build servers build theirs.

| | |
|---|---|
| **Python** | 3.13 |
| **System** | glibc 2.28 or newer: Ubuntu 20.04+, Debian 11+, RHEL 8+ |
| **GPU** | CUDA and OptiX on DGX Spark, Grace Hopper, Grace Blackwell, RTX Blackwell and Jetson Orin; PTX for newer GPUs |
| **Runtime** | the NVIDIA driver; no CUDA toolkit |

## Install

The wheels are on [Releases](https://github.com/SEA-AI/bpy-linux-aarch64/releases) and on a package index:

```bash
pip install bpy --extra-index-url https://sea-ai.github.io/bpy-linux-aarch64/simple/
```

With uv, take only `bpy` on Linux aarch64 from the index and everything else from PyPI:

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

## Build

On any aarch64 Linux host with Docker; no GPU needed:

```bash
./build.sh            # the tag in versions.env
./build.sh v5.2.4     # any other Blender tag
```

The wheel lands in `work/dist/` with a `.buildinfo` file listing every commit and version that went in. `work/` keeps sources and objects, so a rebuild is incremental.

## How it differs from Blender's build

The build environment (Rocky 8), CUDA and OptiX versions, CMake presets and wheel packaging all come from the tag being built, as on [Blender's buildbot](https://projects.blender.org/infrastructure/blender-devops). Four things differ, because Linux aarch64 needs them:

| | Blender | Here |
|---|---|---|
| **Libraries** | `lib/linux_x64`, pinned per tag | `lib-linux_arm64` at the head of the release branch, recorded in each release |
| **OptiX** | NVIDIA's SDK installer | Headers from [NVIDIA/optix-dev](https://github.com/NVIDIA/optix-dev); NVIDIA ships no Linux aarch64 installer |
| **GPU backends** | CUDA, OptiX, HIP, oneAPI | CUDA and OptiX; AMD and Intel ship no Linux aarch64 toolchains |
| **CUDA kernels** | x86 desktop GPUs | `sm_87`, `sm_90`, `sm_100`, `sm_120`, `sm_121`, PTX `compute_87` ([versions.env](versions.env)) |

## Publish

After `./build.sh`, write each wheel's metadata beside it and release both:

```bash
tag=v5.2.4
uvx ghr-pypi extract-meta work/dist/
gh release create "$tag" work/dist/bpy-"${tag#v}"-*.whl work/dist/bpy-"${tag#v}"-*.whl.metadata \
    --title "bpy ${tag#v}" --notes-file "work/dist/$tag.buildinfo"
```

Publishing the release rebuilds the index: [`pages.yml`](.github/workflows/pages.yml) runs [ghr-pypi](https://ghr-pypi.readthedocs.io/) and deploys to GitHub Pages. The `.metadata` file (PEP 658) lets a resolver read `bpy`'s dependencies without downloading the wheel.

## Licence

GPL-2.0-or-later, as Blender. Blender is a trademark of the Blender Foundation; this project is not affiliated with it.
