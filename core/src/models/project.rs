use super::ScheduledDate;
use chrono::NaiveDate;
use serde::{Deserialize, Serialize};
use std::str::FromStr;
use uuid::Uuid;

// ============================================================================
// ProjectStatus
// ============================================================================

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

#[cfg(test)]
mod tests {
    use super::*;

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
}
