#!/bin/zsh
export PATH="$HOME/development/bin:$HOME/development/flutter/bin:$PATH"

echo "=================================================="
echo " 🚀 Launching Aetron (Supabase & Native Google Sign-In)"
echo " Tips:"
echo "   - Normal Debug : ./run.sh"
echo "   - 120fps Smooth: ./run.sh --profile"
echo "   - Final Release: ./run.sh --release"
echo "   - Clean Build  : ./run.sh --clean --release"
echo "=================================================="

CLEAN_BUILD=false
BUILD_IOS_ONLY=false
ARGS=()

for arg in "$@"; do
  if [ "$arg" = "--clean" ]; then
    CLEAN_BUILD=true
  elif [ "$arg" = "--build-ios-only" ]; then
    BUILD_IOS_ONLY=true
  else
    ARGS+=("$arg")
  fi
done

if [ "$CLEAN_BUILD" = true ]; then
  echo "🧹 Cleaning previous build cache & artifacts..."
  flutter clean
  flutter pub get
fi

GIT_COMMIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
GIT_DIRTY=$(git diff-index --quiet HEAD -- 2>/dev/null && echo "" || echo "-dirty")
GIT_PROVENANCE="${GIT_COMMIT_SHA}${GIT_DIRTY}"

if [ "$BUILD_IOS_ONLY" = true ]; then
  FLUTTER_COMMAND=(build ios)
else
  FLUTTER_COMMAND=(run)
fi

flutter "${FLUTTER_COMMAND[@]}" \
  --dart-define=SUPABASE_URL=https://xsqptdzselqyefpmdozz.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhzcXB0ZHpzZWxxeWVmcG1kb3p6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAyNjU4MjEsImV4cCI6MjA4NTg0MTgyMX0.MfdUQpEDB4m5d7xv4wmjKf52sRmapewG-r1ecW6Hndk \
  --dart-define=GOOGLE_WEB_CLIENT_ID=741155040974-vj5atqn3ev6ehnnd15k1a93hi2thkj0o.apps.googleusercontent.com \
  --dart-define=GOOGLE_IOS_CLIENT_ID=741155040974-jvfb8ca41otk67f9pp1st5aqcp3mdqn9.apps.googleusercontent.com \
  --dart-define=GIT_COMMIT_SHA="$GIT_PROVENANCE" \
  --dart-define=FLOWFIT_SOURCE_FINGERPRINT="$GIT_PROVENANCE" \
  "${ARGS[@]}"
