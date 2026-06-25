#!/usr/bin/env bash
# Builds the Flutter Web app on Vercel's build container.
#
# Vercel has no native Flutter buildpack and this repo's /flutter SDK
# checkout is gitignored (it's ~1GB+ of vendored SDK, not meant to be
# committed), so the SDK is fetched fresh on every build instead. Pinned
# to the exact version this project was developed against to avoid a
# newer Flutter/Dart release silently changing behavior.
set -euo pipefail

FLUTTER_VERSION="3.44.2"
FLUTTER_DIR="$HOME/flutter-sdk"

if [ ! -d "$FLUTTER_DIR" ]; then
  git clone https://github.com/flutter/flutter.git \
    -b "$FLUTTER_VERSION" --depth 1 "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

flutter config --enable-web --no-analytics
flutter pub get
flutter build web --release
