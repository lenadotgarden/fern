use std::str::FromStr;

use chrono::NaiveDate;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

// --- Enums ---

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum ProjectStatus {
    Active,
    Someday,
    Logbook,
    Trash,
}

impl ProjectStatus {
    pub fn as_str(&self) -> &'static str {
        match self {
            ProjectStatus::Active => "Active",
            ProjectStatus::Someday => "Someday",
            ProjectStatus::Logbook => "Logbook",
            ProjectStatus::Trash => "Trash",
        }
    }
}

impl FromStr for ProjectStatus {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "Active" => Ok(ProjectStatus::Active),
            "Someday" => Ok(ProjectStatus::Someday),
            "Logbook" => Ok(ProjectStatus::Logbook),
            "Trash" => Ok(ProjectStatus::Trash),
            other => Err(format!("Unknown ProjectStatus: '{}'", other)),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum TaskStatus {
    Inbox,
    Active,
    Logbook,
    Trash,
}

impl TaskStatus {
    pub fn as_str(&self) -> &'static str {
        match self {
            TaskStatus::Inbox => "Inbox",
            TaskStatus::Active => "Active",
            TaskStatus::Logbook => "Logbook",
            TaskStatus::Trash => "Trash",
        }
    }
}

impl FromStr for TaskStatus {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "Inbox" => Ok(TaskStatus::Inbox),
            "Active" => Ok(TaskStatus::Active),
            "Logbook" => Ok(TaskStatus::Logbook),
            "Trash" => Ok(TaskStatus::Trash),
            other => Err(format!("Unknown TaskStatus: '{}'", other)),
        }
    }
}

// --- Structs ---

/// An Area is a top-level organisational container (e.g. "Work", "Personal").
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Area {
    pub id: String,
    pub title: String,
    pub notes: String,
}

impl Area {
    /// Creates a new Area with a freshly generated UUIDv7.
    pub fn new(title: impl Into<String>) -> Self {
        Area {
            id: Uuid::now_v7().to_string(),
            title: title.into(),
            notes: String::new(),
        }
    }
}

/// A Project groups a set of Tasks under a goal, optionally belonging to an Area.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Project {
    pub id: String,
    pub area_id: Option<String>,
    pub title: String,
    pub notes: String,
    pub deadline: Option<NaiveDate>,
    pub status: ProjectStatus,
}

impl Project {
    /// Creates a new active Project with a freshly generated UUIDv7.
    pub fn new(title: impl Into<String>) -> Self {
        Project {
            id: Uuid::now_v7().to_string(),
            area_id: None,
            title: title.into(),
            notes: String::new(),
            deadline: None,
            status: ProjectStatus::Active,
        }
    }
}

/// A Task is the most granular unit of work.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Task {
    pub id: String,
    pub project_id: Option<String>,
    pub area_id: Option<String>,
    pub title: String,
    pub notes: String,
    pub start_date: Option<NaiveDate>,
    pub deadline: Option<NaiveDate>,
    /// Estimated duration in minutes.
    pub estimated_time: Option<i64>,
    /// Actual time spent in minutes.
    pub spent_time: Option<i64>,
    pub status: TaskStatus,
}

impl Task {
    /// Creates a new Task landing in the Inbox with a freshly generated UUIDv7.
    pub fn new(title: impl Into<String>) -> Self {
        Task {
            id: Uuid::now_v7().to_string(),
            project_id: None,
            area_id: None,
            title: title.into(),
            notes: String::new(),
            start_date: None,
            deadline: None,
            estimated_time: None,
            spent_time: None,
            status: TaskStatus::Inbox,
        }
    }
}

// --- Tests ---

#[cfg(test)]
mod tests {
    use super::*;

    // --- ProjectStatus ---

    #[test]
    fn test_project_status_round_trip() {
        let statuses = [
            ProjectStatus::Active,
            ProjectStatus::Someday,
            ProjectStatus::Logbook,
            ProjectStatus::Trash,
        ];
        for status in &statuses {
            let s = status.as_str();
            let parsed = ProjectStatus::from_str(s).expect("should parse back");
            assert_eq!(status, &parsed);
        }
    }

    #[test]
    fn test_project_status_from_invalid_str_returns_error() {
        let result = ProjectStatus::from_str("InvalidStatus");
        assert!(result.is_err());
    }

    // --- TaskStatus ---

    #[test]
    fn test_task_status_round_trip() {
        let statuses = [
            TaskStatus::Inbox,
            TaskStatus::Active,
            TaskStatus::Logbook,
            TaskStatus::Trash,
        ];
        for status in &statuses {
            let s = status.as_str();
            let parsed = TaskStatus::from_str(s).expect("should parse back");
            assert_eq!(status, &parsed);
        }
    }

    #[test]
    fn test_task_status_from_invalid_str_returns_error() {
        let result = TaskStatus::from_str("Done");
        assert!(result.is_err());
    }

    // --- Area ---

    #[test]
    fn test_area_new_has_valid_uuid_and_empty_notes() {
        let area = Area::new("Work");
        assert_eq!(area.title, "Work");
        assert!(area.notes.is_empty());
        // A UUIDv7 is a valid UUID — parse must succeed.
        assert!(uuid::Uuid::parse_str(&area.id).is_ok());
    }

    #[test]
    fn test_two_areas_have_distinct_ids() {
        let a1 = Area::new("Work");
        let a2 = Area::new("Personal");
        assert_ne!(a1.id, a2.id);
    }

    // --- Project ---

    #[test]
    fn test_project_new_defaults_to_active_status() {
        let project = Project::new("Launch website");
        assert_eq!(project.status, ProjectStatus::Active);
        assert!(project.area_id.is_none());
        assert!(project.deadline.is_none());
    }

    #[test]
    fn test_project_new_has_valid_uuid() {
        let project = Project::new("Launch website");
        assert!(uuid::Uuid::parse_str(&project.id).is_ok());
    }

    // --- Task ---

    #[test]
    fn test_task_new_lands_in_inbox() {
        let task = Task::new("Buy groceries");
        assert_eq!(task.status, TaskStatus::Inbox);
        assert!(task.project_id.is_none());
        assert!(task.area_id.is_none());
        assert!(task.start_date.is_none());
        assert!(task.deadline.is_none());
        assert!(task.estimated_time.is_none());
        assert!(task.spent_time.is_none());
    }

    #[test]
    fn test_task_new_has_valid_uuid() {
        let task = Task::new("Write tests");
        assert!(uuid::Uuid::parse_str(&task.id).is_ok());
    }
}
