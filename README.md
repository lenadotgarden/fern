# fern 🌿

A FOSS productivity app based on the features SuperProductivity and the design philosophy of Things 3 based on Rust and native code (SwiftUI).

## Community

Here is the discord server: https://discord.gg/6UxSXPrtcH
I'm thinking of buying a domain name for the project, I might wait a little.

# Pricing

fern is, and will always, be free.

# Tech Stack

- Core: Rust (libcore)
- Storage: SQLite with UUIDv7
- Frontends: Swift (macOS/iOS), Rust/Gtk (Linux)

# Project Structure

## Repository Architecture

- `/core`: Rust library containing all business logic, SQLite database operations, and uniFFI bindings.
- `/apple`: Swift/SwiftUI frontend for iOS and macOS. Contains no business logic.
- `/linux`: Tauri frontend for Linux desktop (Vue/React + Rust).
- `/docs`: Documentation, architecture decisions (ADRs), and strict workflow guidelines.
