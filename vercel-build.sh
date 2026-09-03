#!/bin/bash

set -e

echo "Installing Flutter..."

git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"

export PATH="$HOME/flutter/bin:$PATH"

flutter --version

echo "Building PayPilot..."

cd paypilot_app

flutter pub get
flutter build web --release

echo "Build complete."
