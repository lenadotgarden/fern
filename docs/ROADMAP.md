# Roadmap - fern 🌿

This document trace fern's evolution. Completed tasks goes to `CHANGELOG.md` after being merged in the main branch.

## Milestone 1: Core & Inbox.

- [x] Init monorepo & doc.
- [x] Define Rust data models (Area, Project, Task).
- [x] Config SQLite db (basic CRUD).
- [ ] Setup `uniFFI` to generate Swift bindings.
- [ ] Crate SwiftUI basic UI (Inbox) connected to Rust core.

## Milestone 2: Things-Like Structure.

- [ ] Implement vues logic of "Today", "Upcoming", "Anytime".
- [ ] Add tags & filter support.
- [ ] Implement "Areas" and "Projects".

## Milestone 3: SuperProductivity-Like Timeblocking & Cal.

- [ ] Add time estimate by tasks in Rust.
- [ ] Add time tracking by tasks in Rust.
- [ ] Create Calendar view.
- [ ] Add Google Cal integration.
- [ ] Create auto-timeblocking like SuperProductivity. (no AI, just logic)

## Backlog

- Self-host sync server. Google Drive?
- Google Calendar bidirectional connectivity.
- Linux Client (Tauri).
- Native Markdown Export.
- MCP/API support.
