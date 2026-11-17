#!/usr/bin/env bash
# Build the bpy wheel for one Blender tag on an aarch64 Linux host with Docker.
#   ./build.sh            the tag in versions.env
#   ./build.sh v5.2.4     any other tag
# The wheel lands in $WORK_DIR/dist (default ./work/dist). Needs ~60 GB free;
# no GPU needed to build.
set -euo pipefail
cd "$(dirname "$0")"

set -a; source versions.env; set +a
BLENDER_TAG=${1:-$BLENDER_TAG}
WORK_DIR=${WORK_DIR:-$PWD/work}

[ "$(uname -m)" = aarch64 ] || { echo "Run on an aarch64 host (or a GitHub ubuntu-24.04-arm runner)." >&2; exit 1; }

# Toolchain versions, from the file Blender's buildbot reads for this tag.
config=$(curl -fsSL "https://raw.githubusercontent.com/blender/blender/${BLENDER_TAG}/build_files/config/pipeline_config.yaml")
yaml_version() { awk -v key="$1:" '$1==key{f=1;next} f&&$1=="version:"{gsub(/[^0-9.]/,"",$2);print $2;exit}' <<<"$config"; }
CUDA_VERSION=$(yaml_version cuda12)
OPTIX_VERSION=$(yaml_version optix)

# lib-linux_arm64 has no submodule pin in Blender's tags, unlike x64. Its
# release branch head is what Blender's arm64 maintainers ship for the series.
series=${BLENDER_TAG#v}; series=${series%.*}
LIB_BRANCH=blender-v${series}-release
LIB_COMMIT=${LIB_COMMIT:-$(git ls-remote https://projects.blender.org/blender/lib-linux_arm64.git "refs/heads/${LIB_BRANCH}" | cut -f1)}
[ -n "$LIB_COMMIT" ] || { echo "No ${LIB_BRANCH} branch in lib-linux_arm64." >&2; exit 1; }

echo "Blender ${BLENDER_TAG}: CUDA ${CUDA_VERSION}, OptiX ${OPTIX_VERSION}, lib-linux_arm64 ${LIB_COMMIT:0:10}"

IMAGE=bpy-linux-aarch64-env:${BLENDER_TAG}
docker build \
    --build-arg BLENDER_TAG="$BLENDER_TAG" \
    --build-arg CUDA_VERSION="$CUDA_VERSION" \
    -t "$IMAGE" .

mkdir -p "$WORK_DIR"
docker run --rm \
    -e BLENDER_TAG -e LIB_BRANCH="$LIB_BRANCH" -e LIB_COMMIT="$LIB_COMMIT" \
    -e CUDA_VERSION="$CUDA_VERSION" -e OPTIX_VERSION="$OPTIX_VERSION" -e CUDA_ARCHS -e LOCAL_VERSION \
    ${JOBS:+-e JOBS="$JOBS"} \
    -v "$WORK_DIR":/work \
    "$IMAGE"

# The container runs as root; hand the results back.
docker run --rm -v "$WORK_DIR":/work --entrypoint chown "$IMAGE" -R "$(id -u):$(id -g)" /work
