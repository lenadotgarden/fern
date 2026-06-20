#!/bin/bash
set -e

echo "Building Rust core for all platforms..."
cd ../../core

# Build for macOS, iOS, and iOS Simulator
cargo build --target aarch64-apple-darwin --release
cargo build --target aarch64-apple-ios --release
cargo build --target aarch64-apple-ios-sim --release

echo "Generating uniFFI bindings..."
# We use the macOS dylib to generate bindings (the header and swift file are platform-agnostic)
cargo run --bin uniffi-bindgen generate --library target/aarch64-apple-darwin/release/libfern_core.dylib --language swift --out-dir ../apple/Shared

echo "Preparing headers..."
mkdir -p ../apple/Shared/include
mv ../apple/Shared/fern_coreFFI.h ../apple/Shared/include/
mv ../apple/Shared/fern_coreFFI.modulemap ../apple/Shared/include/module.modulemap

echo "Creating XCFramework..."
rm -rf ../apple/FernCore.xcframework
xcodebuild -create-xcframework \
    -library target/aarch64-apple-darwin/release/libfern_core.a -headers ../apple/Shared/include \
    -library target/aarch64-apple-ios/release/libfern_core.a -headers ../apple/Shared/include \
    -library target/aarch64-apple-ios-sim/release/libfern_core.a -headers ../apple/Shared/include \
    -output ../apple/FernCore.xcframework

echo "XCFramework created successfully!"
