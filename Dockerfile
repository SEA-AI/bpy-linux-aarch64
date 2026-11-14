# Blender's own Linux build environment (Rocky 8, glibc 2.28), from its setup
# script at the tag being built. The wheel then installs on any distro with
# glibc >= 2.28.
FROM rockylinux/rockylinux:8

ARG BLENDER_TAG
# From the tag's pipeline_config.yaml, e.g. 12.9.1.
ARG CUDA_VERSION

# The setup script pins its own CUDA; buildbot compiles with the one
# pipeline_config.yaml names, so install that one instead.
RUN curl -fsSL -o /tmp/setup.sh \
        "https://raw.githubusercontent.com/blender/blender/${BLENDER_TAG}/build_files/build_environment/linux/linux_rocky8_setup.sh" \
    && CUDA_DASH="$(echo "${CUDA_VERSION}" | cut -d. -f1,2 | tr . -)" \
    && sed -i -E "s/(cuda-\*-|cuda-toolkit-)[0-9]+-[0-9]+/\1${CUDA_DASH}/g" /tmp/setup.sh \
    && bash /tmp/setup.sh \
    && dnf clean all && rm -rf /var/cache/dnf /tmp/setup.sh

COPY scripts/build-wheel.sh /usr/local/bin/build-wheel.sh
COPY cmake/linux_aarch64.cmake /opt/bpy/linux_aarch64.cmake

WORKDIR /work
ENTRYPOINT ["scl", "enable", "gcc-toolset-14", "--", "/usr/local/bin/build-wheel.sh"]
