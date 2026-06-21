use super::ScheduledDate;
use chrono::NaiveDate;
use serde::{Deserialize, Serialize};
use std::str::FromStr;
use uuid::Uuid;

// ============================================================================
// TaskStatus
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
    /// Sorting position for manual ordering
    pub position: f64,
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
            position: 0.0,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

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
