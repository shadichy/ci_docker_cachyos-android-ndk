FROM ghcr.io/shadichy/cachyos-android-ci:latest

# Install paru, sudo, repo and git
RUN pacman -Syyu --noconfirm --needed paru sudo repo git

# Switch to builder user
USER builder
WORKDIR /home/builder

# Install android-ndk-beta, android-sdk and go-android-bin from AUR
# We use --noconfirm --skipreview --batchinstall to avoid interactive prompts
RUN paru -S --noconfirm --skipreview --batchinstall --needed android-ndk android-ndk-beta android-sdk go-android-bin nasm yasm meson ninja mesa glu libdrm libva dav1d libx86 libpulse alsa-lib libxv libxcb libvdpau libglvnd cmake

# Set environment variables
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_NDK_HOME=/opt/android-ndk
ENV PATH=$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools:$ANDROID_NDK_HOME

# Copy manifest and sync aosptree
USER root
RUN mkdir -p /aosptree /tmp/manifest
COPY manifest.xml /tmp/manifest/default.xml
WORKDIR /tmp/manifest
RUN git config --global user.email "ci@example.com"
RUN git config --global user.name "CI Builder"
RUN git init
RUN git add .
RUN git commit -m "Initial commit"
WORKDIR /aosptree
RUN repo init -u /tmp/manifest --depth 1
RUN repo sync -c -j$(nproc) --no-clone-bundle --no-tags --fail-fast --optimized-fetch --prune

# Link prebuilt go
USER root
RUN mkdir -p /aosptree/prebuilts/go/
RUN ln -sf /opt/android/go /aosptree/prebuilts/go/linux-x86

# Final cleanup
RUN yes | paru -Scc
