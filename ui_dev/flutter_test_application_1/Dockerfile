FROM ubuntu:20.04

# Set up environment
ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/root/.pub-cache/bin:/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Install necessary packages
RUN apt-get update && apt-get install -y \
  curl \
  git \
  unzip \
  xz-utils \
  zip \
  libglu1-mesa \
  openjdk-8-jdk \
  wget \
  clang \
  cmake \
  ninja-build \
  pkg-config \
  libgtk-3-dev \
  liblzma-dev

# Set up Android SDK
ENV ANDROID_SDK_ROOT="/opt/android-sdk"
RUN mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools
ENV ANDROID_SDK_TOOLS_VERSION="7583922"

# Download Android SDK tools
RUN wget -q https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_SDK_TOOLS_VERSION}_latest.zip -O cmdline-tools.zip && \
    unzip cmdline-tools.zip -d ${ANDROID_SDK_ROOT}/cmdline-tools && \
    mv ${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools ${ANDROID_SDK_ROOT}/cmdline-tools/tools && \
    rm cmdline-tools.zip

ENV PATH="${ANDROID_SDK_ROOT}/cmdline-tools/tools/bin:${PATH}"

# Accept licenses and install Android SDK packages
RUN yes | sdkmanager --licenses && \
    sdkmanager "platform-tools" \
        "platforms;android-31" \
        "build-tools;31.0.0"

# Download Flutter SDK
RUN git clone https://github.com/flutter/flutter.git -b stable /usr/local/flutter

# Pre-download Flutter artifacts
RUN flutter doctor && \
    flutter config --no-analytics && \
    flutter precache

# Set up a working directory
WORKDIR /app

# Copy the Flutter project
COPY . .

# Get Flutter packages
RUN flutter pub get

# Build the Android APK
RUN flutter build apk --release

# Command to run when container starts
CMD ["flutter", "run", "-d", "android"]
