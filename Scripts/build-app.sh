#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
build_dir="$project_dir/.build"
app_dir="$build_dir/Window Gaffer.app"
contents_dir="$app_dir/Contents"
macos_dir="$contents_dir/MacOS"
resources_dir="$contents_dir/Resources"
cache_dir="${TMPDIR:-/tmp}/window-gaffer-spm-cache"
config_dir="${TMPDIR:-/tmp}/window-gaffer-spm-config"
security_dir="${TMPDIR:-/tmp}/window-gaffer-spm-security"
module_cache_dir="${TMPDIR:-/tmp}/window-gaffer-clang-cache"

mkdir -p "$cache_dir" "$config_dir" "$security_dir" "$module_cache_dir"

CLANG_MODULE_CACHE_PATH="$module_cache_dir" swift build \
    --package-path "$project_dir" \
    --configuration release \
    --disable-sandbox \
    --cache-path "$cache_dir" \
    --config-path "$config_dir" \
    --security-path "$security_dir" \
    --scratch-path "$build_dir" \
    -debug-info-format none

rm -rf "$app_dir"
mkdir -p "$macos_dir" "$resources_dir"
cp "$build_dir/release/WindowGaffer" "$macos_dir/WindowGaffer"
cp "$project_dir/Configuration/Info.plist" "$contents_dir/Info.plist"

xcrun actool "$project_dir/Assets/WindowGafferAssets.xcassets" \
    --compile "$resources_dir" \
    --platform macosx \
    --minimum-deployment-target 27.0 \
    --app-icon AppIcon \
    --output-partial-info-plist "$build_dir/asset-info.plist"

codesign --force --sign - "$app_dir"

print "$app_dir"
