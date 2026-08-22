#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 <rust-manifest> <output-library> <target-dir>" >&2
  exit 64
fi

manifest="$1"
output="$2"
target_dir="$3"
platform="${PLATFORM_NAME:-}"
archs="${ARCHS:-}"

if [[ -z "$platform" || -z "$archs" ]]; then
  echo "PLATFORM_NAME and ARCHS must be provided by Xcode" >&2
  exit 64
fi

case "$platform" in
  iphoneos)
    target_for_arch() {
      case "$1" in
        arm64) echo "aarch64-apple-ios" ;;
        *) echo "unsupported iOS device architecture: $1" >&2; return 1 ;;
      esac
    }
    ;;
  iphonesimulator)
    target_for_arch() {
      case "$1" in
        arm64) echo "aarch64-apple-ios-sim" ;;
        x86_64) echo "x86_64-apple-ios" ;;
        *) echo "unsupported iOS simulator architecture: $1" >&2; return 1 ;;
      esac
    }
    ;;
  macosx)
    target_for_arch() {
      case "$1" in
        arm64) echo "aarch64-apple-darwin" ;;
        x86_64) echo "x86_64-apple-darwin" ;;
        *) echo "unsupported macOS architecture: $1" >&2; return 1 ;;
      esac
    }
    ;;
  *)
    echo "unsupported Darwin platform: $platform" >&2
    exit 64
    ;;
esac

mkdir -p "$(dirname "$output")" "$target_dir"
libraries=()

for arch in $archs; do
  target="$(target_for_arch "$arch")"
  rustup target add "$target"
  CARGO_TARGET_DIR="$target_dir" cargo build \
    --manifest-path "$manifest" \
    --target "$target" \
    --release
  libraries+=("$target_dir/$target/release/libdxtr_card_scan_processor.a")
done

if [[ ${#libraries[@]} -eq 1 ]]; then
  cp "${libraries[0]}" "$output"
else
  xcrun lipo -create "${libraries[@]}" -output "$output"
fi
