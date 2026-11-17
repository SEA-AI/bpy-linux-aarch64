#!/usr/bin/env bash
# Runs inside the build image. Mirrors Blender's buildbot worker
# (projects.blender.org/infrastructure/blender-devops, buildbot/worker/blender:
# compile.py and pack.py) for a Linux python-module build. Departures are
# marked "ARM:".
#
# /work persists between runs: sources, libraries and object files are reused.
set -euo pipefail

: "${BLENDER_TAG:?}" "${LIB_BRANCH:?}" "${LIB_COMMIT:?}" "${CUDA_VERSION:?}" "${OPTIX_VERSION:?}" "${CUDA_ARCHS:?}" "${LOCAL_VERSION:?}"
SRC=/work/blender
BUILD=/work/build/$BLENDER_TAG
INSTALL=/work/install/$BLENDER_TAG
DIST=/work/dist
JOBS=${JOBS:-$(nproc)}
CUDA=/usr/local/cuda-$(echo "$CUDA_VERSION" | cut -d. -f1,2)

stage() { printf '\n==> %s\n' "$*"; }

# /work belongs to the host user; the container runs as root.
git config --global --add safe.directory '*'

stage "Blender ${BLENDER_TAG}"
# projects.blender.org, not the GitHub mirror: the mirror lacks the LFS assets.
if [ ! -d "$SRC/.git" ]; then
    git clone --depth 1 --branch "$BLENDER_TAG" https://projects.blender.org/blender/blender.git "$SRC"
else
    git -C "$SRC" fetch --depth 1 origin tag "$BLENDER_TAG"
    git -C "$SRC" checkout -q -f "$BLENDER_TAG"
fi

# ARM: buildbot builds the tag as is. These fix bugs Blender has not fixed yet;
# each patch says which.
stage "Patches"
for patch in /opt/bpy/patches/*.patch; do
    echo "$(basename "$patch")"
    git -C "$SRC" apply "$patch"
done

# ARM: buildbot gets libraries from the tag's submodule pin; arm64 has none.
stage "lib-linux_arm64 ${LIB_BRANCH} @ ${LIB_COMMIT:0:10}"
LIB=$SRC/lib/linux_arm64
if [ ! -d "$LIB/.git" ]; then
    GIT_LFS_SKIP_SMUDGE=1 git clone --branch "$LIB_BRANCH" https://projects.blender.org/blender/lib-linux_arm64.git "$LIB"
fi
GIT_LFS_SKIP_SMUDGE=1 git -C "$LIB" fetch origin "$LIB_BRANCH"
GIT_LFS_SKIP_SMUDGE=1 git -C "$LIB" checkout -q "$LIB_COMMIT"
git -C "$LIB" lfs pull

# ARM: buildbot installs NVIDIA's OptiX SDK, which has no ARM Linux installer.
# Cycles needs only its headers, which NVIDIA publishes as NVIDIA/optix-dev.
stage "OptiX ${OPTIX_VERSION} headers"
OPTIX=/work/optix-dev
if [ ! -d "$OPTIX/.git" ]; then
    git clone https://github.com/NVIDIA/optix-dev.git "$OPTIX"
fi
git -C "$OPTIX" fetch --tags origin
git -C "$OPTIX" checkout -q "v${OPTIX_VERSION}"

# compile.py: clean_directories, cmake_configure
stage "Configure (CUDA ${CUDA_VERSION}: ${CUDA_ARCHS})"
rm -rf "$INSTALL" "$BUILD/CMakeCache.txt" "$BUILD/tests" "$BUILD"/source/creator/buildinfo.h*
mkdir -p "$BUILD"
cmake -S "$SRC" -B "$BUILD" \
    -C "$SRC/build_files/buildbot/config/blender_linux.cmake" \
    -C "$SRC/build_files/cmake/config/bpy_module.cmake" \
    -DWITH_INSTALL_PORTABLE=ON \
    -G Ninja \
    -C /opt/bpy/linux_aarch64.cmake \
    -DCMAKE_BUILD_TYPE:STRING=Release \
    -DCMAKE_INSTALL_PREFIX="$INSTALL" \
    -DWITH_INSTALL_COPYRIGHT=ON \
    -DWITH_GTESTS=OFF \
    -DWITH_CYCLES_CUDA_BINARIES=ON \
    -DOPTIX_ROOT_DIR:PATH="$OPTIX" \
    -DWITH_STRICT_BUILD_OPTIONS=ON \
    -DCUDA_HOST_COMPILER=/usr/bin/gcc \
    -DCUDA_TOOLKIT_ROOT_DIR:PATH="$CUDA" \
    -DCUDA_NVCC_EXECUTABLE:FILEPATH="$CUDA/bin/nvcc" \
    -DCYCLES_CUDA_BINARIES_ARCH="$CUDA_ARCHS"

# compile.py: cmake_build with install
stage "Build (${JOBS} jobs)"
cmake --build "$BUILD" --config Release --parallel "$JOBS" --target install -- -k 50

# pack.py: pack_python_module. The worker's Python has setuptools; Rocky 8's
# 3.6 is too old for make_bpy_wheel.py, so use the Python the libraries ship.
stage "Wheel"
PY=$(ls "$LIB"/python/bin/python3.* | grep -E 'python3\.[0-9]+$' | head -1)
"$PY" -m venv /work/wheel-env
/work/wheel-env/bin/pip install -q setuptools wheel
mkdir -p "$DIST"
# ARM: the local version marks the patched build.
sed -i "s/version=blender_version_str,/version=blender_version_str + \"+${LOCAL_VERSION}\",/" \
    "$SRC/build_files/utils/make_bpy_wheel.py"
grep -q "+${LOCAL_VERSION}" "$SRC/build_files/utils/make_bpy_wheel.py"
/work/wheel-env/bin/python "$SRC/build_files/utils/make_bpy_wheel.py" "$INSTALL" \
    --build-dir "$BUILD" --output-dir "$DIST"

# What went into the wheel, for the release notes.
cat > "$DIST/${BLENDER_TAG}.buildinfo" <<EOF
BLENDER_TAG=${BLENDER_TAG}
BLENDER_COMMIT=$(git -C "$SRC" rev-parse HEAD)
PATCHES="$(cd /opt/bpy/patches && echo *.patch)"
LIB_BRANCH=${LIB_BRANCH}
LIB_COMMIT=${LIB_COMMIT}
CUDA_VERSION=${CUDA_VERSION}
NVCC_VERSION=$("$CUDA/bin/nvcc" --version | sed -n 's/.*release .*, V\([0-9.]*\).*/\1/p')
OPTIX_VERSION=${OPTIX_VERSION}
CUDA_ARCHS="${CUDA_ARCHS}"
EOF
ls -lh "$DIST"
