FROM ghcr.io/shadichy/cachyos-ci:latest

# Install paru and sudo
RUN pacman -Sy --noconfirm paru sudo

# Create a builder user for AUR packages
RUN useradd -m builder && \
    echo "builder ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builder

# Switch to builder user
USER builder
WORKDIR /home/builder

# Android SDK/NDK + native (C/C++) build tooling used by the APK CI jobs.
# rust/rustup intentionally NOT installed here: it is already provided by
# the base image environment (skip entirely per fleet policy).
# We use --noconfirm --skipreview --batchinstall to avoid interactive prompts
RUN paru -S --noconfirm --skipreview --batchinstall \
    android-ndk android-ndk-beta android-sdk android-sdk-build-tools \
    android-platform{,-{32,33,34,35,36}} jdk17-openjdk jdk8-openjdk \
    cmake ninja make git unzip zip patch which go

# bp2ninja: Android.bp -> ninja. Used to build the Soong-only apps and,
# crucially, their JNI shared libraries (libjni_*.so, libgiftranscode.so, ...)
RUN git clone --depth 1 https://github.com/shadichy/bp2ninja bp2ninja && \
    cd bp2ninja && \
    go build -trimpath -o /home/builder/.local/bin/bp2ninja ./cmd/bp2ninja && \
    cd .. && rm -rf bp2ninja

# Set environment variables
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_NDK_HOME=/opt/android-ndk
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk
ENV PATH=/home/builder/.local/bin:$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools:$ANDROID_NDK_HOME

# Switch back to root for final cleanup or further system tasks if needed
USER root
RUN yes | paru -Scc

# bp2ninja must be usable by CI steps running as root too
RUN install -m755 /home/builder/.local/bin/bp2ninja /usr/local/bin/bp2ninja

# Set Java version (Gradle 8.x / AGP 8.x need 17; jdk8 kept for legacy tools)
RUN archlinux-java set java-17-openjdk

# --- Android SDK licenses + components -------------------------------------
# Modern cmdline-tools: the legacy tools/bin/sdkmanager cannot run on JDK17
# (missing JAXB) and predates today's repository schema.  Licenses are accepted
# non-interactively here so gradle never has to download anything at build time.
RUN curl -fsSL -o /tmp/cmdline-tools.zip \
        https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip && \
    mkdir -p /opt/android-sdk/cmdline-tools && \
    unzip -q /tmp/cmdline-tools.zip -d /opt/android-sdk/cmdline-tools && \
    mv /opt/android-sdk/cmdline-tools/cmdline-tools /opt/android-sdk/cmdline-tools/latest && \
    rm -f /tmp/cmdline-tools.zip && \
    yes | /opt/android-sdk/cmdline-tools/latest/bin/sdkmanager --licenses

# Build-tools requested by AGP defaults: 33.0.1 (AGP 8.1.x), 34.0.0
# (AGP 8.2-8.5), 35.0.0 (AGP 8.6/8.7); platform-tools for adb/fastboot.
RUN /opt/android-sdk/cmdline-tools/latest/bin/sdkmanager \
        "platform-tools" \
        "build-tools;33.0.1" "build-tools;34.0.0" "build-tools;35.0.0"

# AGP 8.1.x resolves the NDK for externalNativeBuild by folder name
# (requests ndk;25.1.8937393 for LatinIME).  Alias it to the image NDK:
# verified locally - AGP accepts the alias, compiles, strips and packages the
# JNI libs, and the new-clang -Wvla-cxx-extension/-Werror collision is handled
# by the workflow's APP_CFLAGS shim.
RUN ln -sfn /opt/android-ndk /opt/android-sdk/ndk/25.1.8937393
