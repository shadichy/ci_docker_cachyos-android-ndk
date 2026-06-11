FROM ghcr.io/shadichy/cachyos-ci:latest

# Install paru and sudo
RUN pacman -Sy --noconfirm paru sudo

# Create a builder user for AUR packages
RUN useradd -m builder && \
    echo "builder ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builder

# Switch to builder user
USER builder
WORKDIR /home/builder

# Install android-ndk-beta and android-sdk from AUR
# We use --noconfirm --skipreview --batchinstall to avoid interactive prompts
RUN paru -S --noconfirm --skipreview --batchinstall android-ndk android-ndk-beta android-sdk android-sdk-build-tools android-tools android-platform-{29,32,33,34,35,36} nasm yasm meson ninja cmake e2fsprogs erofs-utils openssl unzip zip go
# No need android-vndk-{32,33,34}

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
