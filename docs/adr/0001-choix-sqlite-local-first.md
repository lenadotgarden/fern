# ADR 0001: SQLite vs Markdown

**Status:** Accepted

**Context:** We needed a storage backend that supports complex querying while remaining local-first.

**Decision:** We chose SQLite over plain Markdown files.

**Consequences:**

1. Better data integrity via relational constraints.
2. Native support for UUIDv7 (time-sortable IDs).
3. Soft deletes allow for easy "Undo" and sync conflict resolution.
