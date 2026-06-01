# ── Stage 1: Build Flutter web ────────────────────────────────────────────────
FROM ubuntu:24.04 AS flutter-build

ENV DEBIAN_FRONTEND=noninteractive
ARG FLUTTER_VERSION=3.44.0

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl xz-utils git unzip \
    && rm -rf /var/lib/apt/lists/*

# Download the Flutter SDK (pinned to FLUTTER_VERSION for reproducibility)
RUN curl -fsSL \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    | tar -xJ -C /opt

ENV PATH="/opt/flutter/bin:$PATH"
ENV FLUTTER_ROOT="/opt/flutter"

# Allow git and flutter to run as root inside the container
RUN git config --global --add safe.directory /opt/flutter
ENV FLUTTER_ALREADY_LOCKED=true

# Pre-download web compile artifacts (cached as a separate layer)
RUN flutter precache --web \
        --no-android --no-ios --no-linux --no-macos --no-windows --no-fuchsia

# Restore pub dependencies (separate layer — only re-runs when pubspec changes)
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Build
COPY lib/    lib/
COPY web/    web/
RUN flutter build web --release --no-wasm-dry-run

# ── Stage 2: AOT-compile the Dart server ──────────────────────────────────────
FROM dart:stable AS dart-build

RUN apt-get update && apt-get install -y --no-install-recommends \
        libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY server/pubspec.yaml server/pubspec.lock server/
RUN cd server && dart pub get --no-precompile

COPY server/ server/
RUN cd server && dart pub get --offline \
 && dart compile exe bin/server.dart -o bin/server

# ── Stage 3: Minimal runtime image ────────────────────────────────────────────
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        libsqlite3-0 \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s libsqlite3.so.0 /usr/lib/$(uname -m)-linux-gnu/libsqlite3.so

WORKDIR /app

COPY --from=dart-build  /app/server/bin/server /app/server
COPY --from=flutter-build /app/build/web        /app/web

RUN mkdir -p /data

ENV PORT=8080
ENV STATIC_PATH=/app/web
ENV DATA_PATH=/data/meetings.db

EXPOSE 8080
CMD ["/app/server"]
