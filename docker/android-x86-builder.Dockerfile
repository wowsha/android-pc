# Android-x86 Jelly Bean predates current Ubuntu build hosts.
# Ubuntu 18.04 matches the upstream project's documented build environment.
FROM ubuntu:18.04

ENV DEBIAN_FRONTEND=noninteractive

# Bionic remains available from the normal Ubuntu archive (it is under ESM,
# not on old-releases). Disable stale Release-file date checks for this
# historical build image, but keep the standard archive/security endpoints.
RUN apt-get -o Acquire::Check-Valid-Until=false update \
    && apt-get install -y --no-install-recommends \
      bc \
      bison \
      build-essential \
      ca-certificates \
      curl \
      flex \
      g++-multilib \
      gcc-multilib \
      git \
      gperf \
      lib32ncurses5-dev \
      lib32stdc++6 \
      lib32z1 \
      libelf-dev \
      libgl1-mesa-dev \
      libncurses5-dev \
      libreadline-dev \
      libssl-dev \
      libx11-dev \
      libxml2-utils \
      make \
      m4 \
      mtools \
      openjdk-8-jdk \
      python \
      python-enum34 \
      python-mako \
      rsync \
      syslinux-utils \
      unzip \
      uuid-dev \
      wget \
      xsltproc \
      zip \
      zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Google's repo launcher. It will fetch the manifest and the
# individual AOSP/Android-x86 Git projects at build time.
RUN curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo \
      -o /usr/local/bin/repo \
    && chmod 0755 /usr/local/bin/repo

# Android's build system refuses to run as root. UID 1001 matches the
# standard GitHub-hosted Linux runner account, so the mounted workspace
# remains writable from both the host and this container.
RUN useradd --create-home --uid 1001 --shell /bin/bash builder

USER builder
ENV HOME=/home/builder
WORKDIR /workspace
