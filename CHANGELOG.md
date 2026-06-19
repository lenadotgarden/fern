# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Defined the "Shared Core" architecture using Rust and SQLite.
- Created baseline repository documentation (`README.md`, `CONTRIBUTING.md`).
- Authored the first Architecture Decision Record (ADR) establishing the Local-First model.
- Implemented Rust data models (`Area`, `Project`, `Task`) with status enums and UUIDv7 generation.
- Configured SQLite database layer with schema initialization (WAL, foreign keys), full CRUD and soft-delete for all three entities.
- Refactored Data Model to strictly follow Things 3 paradigm (derived views instead of strict statuses).
- Introduced `ScheduledDate` enum to correctly parse Dates, Dates with Time, and Someday.
- Implemented robust SQL queries for dynamic views (Inbox, Today, Upcoming, Anytime, Someday, Logbook, Trash).
- Added `is_trashed` to Projects/Tasks and `is_archived` to Areas.
- Achieved 100% test passing rate on 50 Rust unit tests (including SQLite timezone edge cases).
