use std::str::FromStr;

use crate::UniffiCustomTypeConverter;
use chrono::{NaiveDate, NaiveTime};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

// Tell uniFFI how to handle NaiveDate and NaiveTime by passing them as Strings over the FFI boundary.
uniffi::custom_type!(NaiveDate, String);
impl UniffiCustomTypeConverter for NaiveDate {
    type Builtin = String;
    fn into_custom(val: Self::Builtin) -> uniffi::Result<Self> {
        val.parse().map_err(|e: chrono::ParseError| e.into())
    }
    fn from_custom(obj: Self) -> Self::Builtin {
        obj.to_string()
    }
}

uniffi::custom_type!(NaiveTime, String);
impl UniffiCustomTypeConverter for NaiveTime {
    type Builtin = String;
    fn into_custom(val: Self::Builtin) -> uniffi::Result<Self> {
        val.parse().map_err(|e: chrono::ParseError| e.into())
    }
    fn from_custom(obj: Self) -> Self::Builtin {
        obj.to_string()
    }
}

// ============================================================================
// TaskStatus & ProjectStatus
//
// These are the ONLY real states an item can be in.
// "Inbox", "Anytime", "Today", "Someday", "Upcoming", "Logbook" and "Trash"
// are all *derived views* computed from the item's fields — not statuses.
//
// Specifically:
//   Inbox   = Todo task with no area, no project, no scheduled_date, not trashed
//   Anytime = Todo task/project with no scheduled_date, not trashed
//   Today   = Todo task with scheduled_date == today, not trashed
//   Upcoming= Todo task with scheduled_date > today, not trashed
//   Someday = Todo task/project with scheduled_date == Someday, not trashed
//   Logbook = task/project with status Done or Cancelled, not trashed
//   Trash   = is_trashed == true  (independent of status)
// ============================================================================

/// Completion state of a Task. The view a task appears in is determined by
/// its other fields (`scheduled_date`, `project_id`, `area_id`, `is_trashed`).
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, uniffi::Enum)]
pub enum TaskStatus {
    Todo,
    Done,
    Cancelled,
}

impl TaskStatus {
    pub fn as_str(&self) -> &'static str {
        match self {
            TaskStatus::Todo => "Todo",
            TaskStatus::Done => "Done",
            TaskStatus::Cancelled => "Cancelled",
        }
    }
}

impl FromStr for TaskStatus {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "Todo" => Ok(TaskStatus::Todo),
            "Done" => Ok(TaskStatus::Done),
            "Cancelled" => Ok(TaskStatus::Cancelled),
            other => Err(format!("Unknown TaskStatus: '{}'", other)),
        }
    }
}

/// Completion state of a Project.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, uniffi::Enum)]
pub enum ProjectStatus {
    Todo,
    Done,
    Cancelled,
}

impl ProjectStatus {
    pub fn as_str(&self) -> &'static str {
        match self {
            ProjectStatus::Todo => "Todo",
            ProjectStatus::Done => "Done",
            ProjectStatus::Cancelled => "Cancelled",
        }
    }
}

impl FromStr for ProjectStatus {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "Todo" => Ok(ProjectStatus::Todo),
            "Done" => Ok(ProjectStatus::Done),
            "Cancelled" => Ok(ProjectStatus::Cancelled),
            other => Err(format!("Unknown ProjectStatus: '{}'", other)),
        }
    }
}

// ============================================================================
// ScheduledDate
//
// A rich date type that encodes "when to work on this item".
// It replaces what used to be a plain `start_date: Option<NaiveDate>` and
// the old `Someday` status variant.
//
// SQLite storage format (TEXT column):
//   NULL                → no scheduled date (item appears in Anytime or Inbox)
//   "someday"           → deferred indefinitely  (item appears in Someday)
//   "YYYY-MM-DD"        → scheduled for a specific day
//   "YYYY-MM-DD HH:MM"  → scheduled at a specific time (future: triggers notification)
// ============================================================================

/// When an item is scheduled to be worked on.
///
/// `None` (absence of this field) means "no date" → Anytime or Inbox.
/// `Someday` means "deferred, no concrete date" → Someday view.
/// `On { date, time }` means "scheduled for this day, optionally at this time".
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, uniffi::Enum)]
pub enum ScheduledDate {
    /// Deferred indefinitely. Item appears in the Someday view.
    Someday,
    /// Scheduled for a specific day, with an optional notification time.
    On {
        date: NaiveDate,
        /// If set, a local notification will fire at this time on `date`.
        time: Option<NaiveTime>,
    },
}

impl ScheduledDate {
    /// Serialises to the SQLite TEXT format.
    pub fn to_db_string(&self) -> String {
        match self {
            ScheduledDate::Someday => "someday".to_string(),
            ScheduledDate::On { date, time: None } => date.to_string(),
            ScheduledDate::On {
                date,
                time: Some(t),
            } => {
                format!("{} {}", date, t.format("%H:%M"))
            }
        }
    }

    /// Deserialises from the SQLite TEXT format.
    pub fn from_db_string(s: &str) -> Result<Self, String> {
        if s == "someday" {
            return Ok(ScheduledDate::Someday);
        }
        // "YYYY-MM-DD HH:MM" — split on the space
        if let Some((date_str, time_str)) = s.split_once(' ') {
            let date = date_str
                .parse::<NaiveDate>()
                .map_err(|e| format!("Invalid date '{}': {}", date_str, e))?;
            let time = NaiveTime::parse_from_str(time_str, "%H:%M")
                .map_err(|e| format!("Invalid time '{}': {}", time_str, e))?;
            return Ok(ScheduledDate::On {
                date,
                time: Some(time),
            });
        }
        // "YYYY-MM-DD" — date only
        let date = s
            .parse::<NaiveDate>()
            .map_err(|e| format!("Invalid scheduled date '{}': {}", s, e))?;
        Ok(ScheduledDate::On { date, time: None })
    }
}

// ============================================================================
// Area
// ============================================================================

/// Top-level organisational container (e.g. "Work", "Personal").
///
/// Areas have no status — they can only be active (visible) or archived
/// (hidden from the sidebar, but all data is preserved).
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, uniffi::Record)]
pub struct Area {
    pub id: String,
    pub title: String,
    pub notes: String,
    /// Archived areas are hidden but never deleted. All their projects and tasks
    /// remain queryable and are preserved for history and future sync.
    pub is_archived: bool,
    /// Manual sort order. Fractional indexing is used for efficient reordering.
    pub position: f64,
}

impl Area {
    pub fn new(title: impl Into<String>) -> Self {
        Area {
            id: Uuid::now_v7().to_string(),
            title: title.into(),
            notes: String::new(),
            is_archived: false,
            position: 0.0,
        }
    }
}

// ============================================================================
// Project
// ============================================================================

/// A goal-oriented collection of Tasks, optionally belonging to an Area.
///
/// # Which view does a project appear in?
///
/// | Condition                                          | View      |
/// |----------------------------------------------------|-----------|
/// | `status=Todo`, `is_trashed=false`, no date         | Anytime   |
/// | `status=Todo`, `is_trashed=false`, date=Someday    | Someday   |
/// | `status=Done\|Cancelled`, `is_trashed=false`       | Logbook   |
/// | `is_trashed=true`                                  | Trash     |
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, uniffi::Record)]
pub struct Project {
    pub id: String,
    pub area_id: Option<String>,
    pub title: String,
    pub notes: String,
    /// When to work on this project. `None` = Anytime, `Someday` = deferred.
    /// Note: this is distinct from `deadline` (which is a hard due date).
    pub scheduled_date: Option<ScheduledDate>,
    pub deadline: Option<NaiveDate>,
    /// The actual completion state. Logbook/Trash are derived from this + `is_trashed`.
    pub status: ProjectStatus,
    /// If true, the project is in the Trash. Independent of `status`:
    /// a Done project can also be trashed (and vice-versa).
    pub is_trashed: bool,
    /// Manual sort order.
    pub position: f64,
}

impl Project {
    pub fn new(title: impl Into<String>) -> Self {
        Project {
            id: Uuid::now_v7().to_string(),
            area_id: None,
            title: title.into(),
            notes: String::new(),
            scheduled_date: None,
            deadline: None,
            status: ProjectStatus::Todo,
            is_trashed: false,
            position: 0.0,
        }
    }
}

// ============================================================================
// Task
// ============================================================================

/// The atomic unit of work.
///
/// # Which view does a task appear in?
///
/// | Condition                                                          | View     |
/// |--------------------------------------------------------------------|----------|
/// | `Todo`, no project, no area, no date, not trashed                 | Inbox    |
/// | `Todo`, `scheduled_date=On{today}`, not trashed                   | Today    |
/// | `Todo`, `scheduled_date=On{future}`, not trashed                  | Upcoming |
/// | `Todo`, `scheduled_date=None`, not trashed                        | Anytime  |
/// | `Todo`, `scheduled_date=Someday`, not trashed                     | Someday  |
/// | `Done` or `Cancelled`, not trashed                                | Logbook  |
/// | `is_trashed=true`                                                  | Trash    |
///
/// A task completed while in the Inbox (no project, no area, no date) will
/// appear in the Logbook — correctly preserving its origin context.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, uniffi::Record)]
pub struct Task {
    pub id: String,
    pub project_id: Option<String>,
    pub area_id: Option<String>,
    pub title: String,
    pub notes: String,
    /// When to work on this task. `None` means Anytime (or Inbox if also unorganised).
    /// `Someday` means deferred indefinitely.
    pub scheduled_date: Option<ScheduledDate>,
    pub deadline: Option<NaiveDate>,
    /// Estimated duration in minutes.
    pub estimated_time: Option<i64>,
    /// Actual time spent in minutes.
    pub spent_time: Option<i64>,
    /// The actual completion state.
    pub status: TaskStatus,
    /// If true, the task is in the Trash. Independent of `status`.
    pub is_trashed: bool,
}

impl Task {
    /// Creates a new task that lands in the Inbox: no project, no area,
    /// no scheduled date, status Todo, not trashed.
    pub fn new(title: impl Into<String>) -> Self {
        Task {
            id: Uuid::now_v7().to_string(),
            project_id: None,
            area_id: None,
            title: title.into(),
            notes: String::new(),
            scheduled_date: None,
            deadline: None,
            estimated_time: None,
            spent_time: None,
            status: TaskStatus::Todo,
            is_trashed: false,
        }
    }
}

// ============================================================================
// Tests
// ============================================================================

#[cfg(test)]
mod tests {
    use super::*;

    // --- TaskStatus ---

    #[test]
    fn test_task_status_round_trip() {
        for status in &[TaskStatus::Todo, TaskStatus::Done, TaskStatus::Cancelled] {
            let s = status.as_str();
            let parsed = TaskStatus::from_str(s).expect("should parse back");
            assert_eq!(status, &parsed);
        }
    }

    #[test]
    fn test_task_status_rejects_old_and_invalid_values() {
        // These were the old variants — guard against accidental re-introduction.
        for old in &["Inbox", "Active", "Someday", "Logbook", "Trash", "", "todo"] {
            assert!(
                TaskStatus::from_str(old).is_err(),
                "Should reject old/invalid value '{}'",
                old
            );
        }
    }

    // --- ProjectStatus ---

    #[test]
    fn test_project_status_round_trip() {
        for status in &[
            ProjectStatus::Todo,
            ProjectStatus::Done,
            ProjectStatus::Cancelled,
        ] {
            let s = status.as_str();
            let parsed = ProjectStatus::from_str(s).expect("should parse back");
            assert_eq!(status, &parsed);
        }
    }

    #[test]
    fn test_project_status_rejects_old_and_invalid_values() {
        for old in &["Active", "Someday", "Logbook", "Trash", "", "done"] {
            assert!(
                ProjectStatus::from_str(old).is_err(),
                "Should reject old/invalid value '{}'",
                old
            );
        }
    }

    // --- ScheduledDate ---

    #[test]
    fn test_scheduled_date_someday_round_trip() {
        let sd = ScheduledDate::Someday;
        let db_str = sd.to_db_string();
        assert_eq!(db_str, "someday");
        assert_eq!(ScheduledDate::from_db_string(&db_str).unwrap(), sd);
    }

    #[test]
    fn test_scheduled_date_date_only_round_trip() {
        let date = NaiveDate::from_ymd_opt(2026, 9, 30).unwrap();
        let sd = ScheduledDate::On { date, time: None };
        let db_str = sd.to_db_string();
        assert_eq!(db_str, "2026-09-30");
        assert_eq!(ScheduledDate::from_db_string(&db_str).unwrap(), sd);
    }

    #[test]
    fn test_scheduled_date_with_time_round_trip() {
        let date = NaiveDate::from_ymd_opt(2026, 9, 30).unwrap();
        let time = NaiveTime::from_hms_opt(14, 30, 0).unwrap();
        let sd = ScheduledDate::On {
            date,
            time: Some(time),
        };
        let db_str = sd.to_db_string();
        assert_eq!(db_str, "2026-09-30 14:30");
        assert_eq!(ScheduledDate::from_db_string(&db_str).unwrap(), sd);
    }

    #[test]
    fn test_scheduled_date_rejects_garbage() {
        assert!(ScheduledDate::from_db_string("not-a-date").is_err());
        assert!(ScheduledDate::from_db_string("2026-99-99").is_err());
        assert!(ScheduledDate::from_db_string("2026-06-20 99:99").is_err());
        assert!(ScheduledDate::from_db_string("").is_err());
    }

    // --- Area ---

    #[test]
    fn test_area_new_defaults() {
        let a = Area::new("Work");
        assert_eq!(a.title, "Work");
        assert!(a.notes.is_empty());
        assert!(!a.is_archived, "new area should not be archived");
        assert!(uuid::Uuid::parse_str(&a.id).is_ok());
    }

    #[test]
    fn test_two_areas_have_distinct_ids() {
        assert_ne!(Area::new("Work").id, Area::new("Personal").id);
    }

    // --- Project ---

    #[test]
    fn test_project_new_defaults() {
        let p = Project::new("Launch website");
        assert_eq!(p.status, ProjectStatus::Todo);
        assert!(p.area_id.is_none());
        assert!(p.scheduled_date.is_none());
        assert!(p.deadline.is_none());
        assert!(!p.is_trashed, "new project should not be trashed");
        assert!(uuid::Uuid::parse_str(&p.id).is_ok());
    }

    #[test]
    fn test_two_projects_have_distinct_ids() {
        assert_ne!(Project::new("A").id, Project::new("B").id);
    }

    // --- Task ---

    #[test]
    fn test_task_new_defaults() {
        let t = Task::new("Buy groceries");
        assert_eq!(t.status, TaskStatus::Todo);
        assert!(t.project_id.is_none());
        assert!(t.area_id.is_none());
        assert!(t.scheduled_date.is_none());
        assert!(t.deadline.is_none());
        assert!(t.estimated_time.is_none());
        assert!(t.spent_time.is_none());
        assert!(!t.is_trashed, "new task should not be trashed");
        assert!(uuid::Uuid::parse_str(&t.id).is_ok());
    }

    #[test]
    fn test_task_in_inbox_has_no_organisation() {
        // A default new task has no project, no area, no date — it's in the Inbox.
        let t = Task::new("Unclassified thought");
        assert!(t.project_id.is_none());
        assert!(t.area_id.is_none());
        assert!(t.scheduled_date.is_none());
    }

    #[test]
    fn test_two_tasks_have_distinct_ids() {
        assert_ne!(Task::new("A").id, Task::new("B").id);
    }
}
