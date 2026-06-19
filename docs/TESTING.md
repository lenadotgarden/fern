# Testing Guide - fern 🌿

The stability of fern relies entirely on TDD (Test-Driven Development). **No business logic should ever be written without its corresponding unit test.**

## 1. Core Tests (Rust)

All the logic lives in the `core/` directory.

- **Run all tests:** `cargo test`
- **Run tests with debug logs:** `RUST_LOG=debug cargo test -- --nocapture`

### Coverage Rule

Every file in `core/src/` must contain a `mod tests { ... }` submodule at the bottom of the file to thoroughly test all public functions.

## 2. UI Tests (Apple/SwiftUI)

Since the UI only handles rendering and passes user actions to the Rust core, tests here focus on integration.

- Use Apple's built-in XCTest framework within Xcode.
- Do not test business logic here (it is already tested in Rust). Only test that the UI responds correctly to state changes and user inputs.
