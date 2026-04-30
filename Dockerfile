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
# We use --noconfirm to avoid interactive prompts
RUN paru -S --noconfirm android-ndk-beta android-sdk

# Set environment variables
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_NDK_HOME=/opt/android-ndk
ENV PATH=$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools:$ANDROID_NDK_HOME

# Switch back to root for final cleanup or further system tasks if needed
USER root
RUN pacman -Scc --noconfirm
