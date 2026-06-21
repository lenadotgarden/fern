use crate::database::Database;
use crate::models::{Area, Project, Task};
use std::sync::{Arc, Mutex};

/// A custom error type that will be exposed to Swift as an Error enum.
#[derive(Debug, thiserror::Error, uniffi::Error)]
pub enum FernError {
    #[error("Database error: {0}")]
    DatabaseError(String),
}

/// A thread-safe API facade for the Swift side.
#[derive(uniffi::Object)]
pub struct FernAPI {
    pub(crate) db: Arc<Mutex<Database>>,
}

#[uniffi::export]
impl FernAPI {
    /// Creates a new in-memory instance for testing.
    #[uniffi::constructor]
    pub fn new_in_memory() -> Result<Arc<Self>, FernError> {
        let db = Database::new_in_memory().map_err(|e| FernError::DatabaseError(e.to_string()))?;
        Ok(Arc::new(Self {
            db: Arc::new(Mutex::new(db)),
        }))
    }

    /// Creates a new persistence instance at the given file path.
    #[uniffi::constructor]
    pub fn new(path: String) -> Result<Arc<Self>, FernError> {
        let db = Database::new(&path).map_err(|e| FernError::DatabaseError(e.to_string()))?;
        Ok(Arc::new(Self {
            db: Arc::new(Mutex::new(db)),
        }))
    }
}

include!("area_api.rs");
include!("project_api.rs");
include!("task_api.rs");

#[cfg(test)]
mod api_tests {
    use super::*;
    use crate::models::{Area, Project, Task};

    #[test]
    fn test_api_initialization() {
        let api = FernAPI::new_in_memory().expect("Should initialize without errors");
        assert_eq!(api.get_today_tasks().unwrap().len(), 0);
    }

    #[test]
    fn test_api_full_task_lifecycle() {
        let api = FernAPI::new_in_memory().unwrap();

        let t = Task::new("Inbox Swift Task");
        let t_id = t.id.clone();
        api.create_task(t).unwrap();

        // 1. Appears in Inbox
        assert_eq!(api.get_inbox_tasks().unwrap().len(), 1);
        assert_eq!(api.get_today_tasks().unwrap().len(), 0);

        // 2. Complete the task
        api.complete_task(t_id.clone()).unwrap();
        assert_eq!(api.get_inbox_tasks().unwrap().len(), 0);
        assert_eq!(api.get_logbook_tasks().unwrap().len(), 1);

        // 3. Trash it
        api.trash_task(t_id).unwrap();
        assert_eq!(api.get_logbook_tasks().unwrap().len(), 0); // Disappears from logbook
    }

    #[test]
    fn test_api_areas_and_projects() {
        let api = FernAPI::new_in_memory().unwrap();
        let area = Area::new("Work");
        let area_id = area.id.clone();
        api.create_area(area).unwrap();
        assert_eq!(api.get_active_areas().unwrap().len(), 1);

        let mut proj = Project::new("Website");
        proj.area_id = Some(area_id.clone());
        let proj_id = proj.id.clone();
        api.create_project(proj).unwrap();
        assert_eq!(api.get_anytime_projects().unwrap().len(), 1);

        api.complete_project(proj_id).unwrap();
        assert_eq!(api.get_anytime_projects().unwrap().len(), 0);

        api.archive_area(area_id).unwrap();
        assert_eq!(api.get_active_areas().unwrap().len(), 0);
    }
}
