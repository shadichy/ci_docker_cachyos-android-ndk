FROM ghcr.io/shadichy/cachyos-ci:latest

# Install paru and sudo
RUN pacman -Sy --noconfirm paru sudo

# Create a builder user for AUR packages
RUN useradd -m builder && \
    echo "builder ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builder

# Ensure portable x86-64-v2 microarchitecture instead of -march=native to prevent SIGILL on non-AVX512 runners
RUN sed -i 's/-march=native/-march=x86-64-v2/g' /etc/makepkg.conf
ENV GOAMD64=v2

# Switch to builder user
USER builder
WORKDIR /home/builder

# Install android-ndk-beta, android-sdk, and host build dependencies for igt-gpu-tools and tooling
# We use --noconfirm --skipreview --batchinstall to avoid interactive prompts
RUN paru -S --noconfirm --skipreview --batchinstall \
    android-ndk android-ndk-beta android-sdk android-sdk-build-tools android-tools \
    android-platform-{29,32,33,34,35,36} android-vndk-{32,33,34} \
    nasm yasm meson ninja cmake e2fsprogs erofs-utils openssl unzip zip go \
    libprocps cairo pixman libunwind valgrind dtc cpputest \
    wayland wayland-protocols xkeyboard-config libbpf libpciaccess pciutils kmod elfutils libdrm \
    glib2 bison flex kotlin llvm clang protobuf

# Setup makeapex
RUN git clone --depth 1 https://github.com/ag-sdc/makeapex makeapex
WORKDIR /home/builder/makeapex/.ci/dist
RUN makepkg -fisd --noconfirm

WORKDIR /home/builder

# Setup apex-install
RUN git clone --depth 1 https://github.com/ag-sdc/apex-install apex-install
WORKDIR /home/builder/apex-install/.ci/dist
RUN makepkg -fisd --noconfirm

WORKDIR /home/builder

# Cleanup
RUN rm -rf makeapex apex-install
RUN yes | paru -Scc
RUN rm -rf .cache /var/cache/pacman/pkg/*

# Switch back to root
USER root
