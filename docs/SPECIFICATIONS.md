# Product Specifications - fern 🌿

This document details the exact features, data structures, and UX requirements for the application. It serves as the ultimate source of truth for the project's scope.

## 1. Core Data Entities

### Task

- **Date** (Start Date)
- **Deadline**
- **Tags**
- **Notes** (markdown compatible)
- **Estimated Time** (minutes)
- **Spent Time** (minutes)

### Project

- **Date**
- **Deadline**
- **Tasks** (Relation)
- **Sections** (To group tasks within a project)
- **Tags**
- **Notes** (markdown compatible)
- **Estimated Time** (Calculated automatically from child tasks)
- **Spent Time** (Calculated automatically from child tasks)

### Area

- **Projects** (Relation)
- **Tags**
- **Notes** (markdown compatible)

## 2. Required Views

- **Inbox:** Default landing for uncategorized tasks.
- **Today:** Tasks scheduled for today.
- **Upcoming:** Timeline of future tasks.
- **Calendar:** Visual timeblocking view.
- **Anytime:** Tasks without a specific date.
- **Someday:** Tasks with no immediate commitment.
- **Logbook:** Completed tasks.
- **Trash:** Deleted items (soft-delete).
- **Kanban View:** Alternative board view for Projects.
- **Eisenhower Matrix:** Urgent vs. Important visualization.

## 3. UX & Interaction Requirements

- **Keyboard-First:** Comprehensive shortcuts for power users.
- **Touch Gestures:** Things 3-inspired mobile interactions (pull-to-add, swipe to schedule).
- **Widgets:** Things 3-inspired mobile Widget.
- **Instant Search:** Zero-latency global search (powered by SQLite).
- **Frictionless Tracking:** Any task can be time-tracked via a global shortcut.

## 4. Timeblocking & Integration

- **Auto-Scheduling:** Automatic timeblocking based on predefined work hours, linked to the calendar tab. It places tasks in order but remains easily adjustable (drag-and-drop).
- **Google Calendar Sync:** Two-way synchronization. Tasks appear in GCal as events, and GCal events reflect in the app's timeline.
