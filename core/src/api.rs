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
    // We wrap the Database in a Mutex because `uniffi::Object` requires Send + Sync.
    // SQLite with rusqlite is Send but not Sync if not configured properly,
    // but Mutex makes it safe to share across Swift threads.
    db: Arc<Mutex<Database>>,
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

    // Example API methods that we will build out via TDD
    // =========================================================================
    // Area API
    // =========================================================================
    pub fn update_project(&self, project: Project) -> Result<(), FernError> {
        let db = self.db.lock().unwrap();
        db.update_project(&project)
            .map(|_| ())
            .map_err(|e| FernError::DatabaseError(e.to_string()))?;
        db.update_tasks_area_for_project(&project.id, project.area_id.as_ref())
            .map(|_| ())
            .map_err(|e| FernError::DatabaseError(e.to_string()))?;
        Ok(())
    }

    pub fn create_area(&self, area: Area) -> Result<(), FernError> {
        self.db
            .lock()
            .unwrap()
            .create_area(&area)
            .map(|_| ())
            .map_err(|e| FernError::DatabaseError(e.to_string()))
    }

    pub fn update_area(&self, area: Area) -> Result<(), FernError> {
        self.db
            .lock()
            .unwrap()
            .update_area(&area)
            .map(|_| ())
            .map_err(|e| FernError::DatabaseError(e.to_string()))
    }
    pub fn get_active_areas(&self) -> Result<Vec<Area>, FernError> {
        self.db
            .lock()
            .unwrap()
            .get_active_areas()
            .map_err(|e| FernError::DatabaseError(e.to_string()))
    }

    // =========================================================================
    // All Queries API
    // =========================================================================
    pub fn get_all_tasks(&self) -> Result<Vec<Task>, FernError> {
        self.db
            .lock()
            .unwrap()
            .get_all_tasks()
            .map_err(|e| FernError::DatabaseError(e.to_string()))
    }

    pub fn get_all_projects(&self) -> Result<Vec<Project>, FernError> {
        self.db
            .lock()
            .unwrap()
            .get_all_projects()
            .map_err(|e| FernError::DatabaseError(e.to_string()))
    }
    pub fn unarchive_area(&self, id: String) -> Result<(), FernError> {
        self.db
            .lock()
            .unwrap()
            .unarchive_area(&id)
            .map_err(|e| FernError::DatabaseError(e.to_string()))?;
        Ok(())
    }

    pub fn update_area_position(&self, id: String, new_position: f64) -> Result<(), FernError> {
        let db = self.db.lock().unwrap();
        let mut area = db
            .get_area(&id)
            .map_err(|e| FernError::DatabaseError(e.to_string()))?
            .ok_or_else(|| FernError::DatabaseError("Area not found".to_string()))?;
        area.position = new_position;
        db.update_area(&area)
            .map(|_| ())
            .map_err(|e| FernError::DatabaseError(e.to_string()))
    }
    pub fn archive_area(&self, id: String) -> Result<(), FernError> {
        self.db
            .lock()
            .unwrap()
            .archive_area(&id)
            .map_err(|e| FernError::DatabaseError(e.to_string()))?;
        Ok(())
    }
    pub fn delete_area(&self, id: String) -> Result<(), FernError> {
        self.db
            .lock()
            .unwrap()
            .delete_area(&id)
            .map_err(|e| FernError::DatabaseError(e.to_string()))?;
        Ok(())
    }

    // =========================================================================
    // Project API
    // =========================================================================
    pub fn create_project(&self, project: Project) -> Result<(), FernError> {
        self.db
            .lock()
            .unwrap()
            .create_project(&project)
            .map(|_| ())
            .map_err(|e| FernError::DatabaseError(e.to_string()))
    }
    pub fn get_anytime_projects(&self) -> Result<Vec<Project>, FernError> {
        self.db
            .lock()
            .unwrap()
            .get_anytime_projects()
            .map_err(|e| FernError::DatabaseError(e.to_string()))
    }
    pub fn complete_project(&self, id: String) -> Result<(), FernError> {
        self.db
            .lock()
            .unwrap()
            .complete_project(&id)
            .map_err(|e| FernError::DatabaseError(e.to_string()))?;
        Ok(())
    }
    pub fn trash_project(&self, id: String) -> Result<(), FernError> {
        self.db
            .lock()
            .unwrap()
            .trash_project(&id)
            .map_err(|e| FernError::DatabaseError(e.to_string()))?;
        Ok(())
    }
    pub fn delete_project(&self, id: String) -> Result<(), FernError> {
        self.db
            .lock()
            .unwrap()
            .delete_project(&id)
            .map_err(|e| FernError::DatabaseError(e.to_string()))?;
        Ok(())
    }
    pub fn restore_project(&self, id: String) -> Result<(), FernError> {
        self.db
            .lock()
            .unwrap()
            .restore_project(&id)
            .map_err(|e| FernError::DatabaseError(e.to_string()))?;
        Ok(())
    }

    pub fn update_project_position(&self, id: String, new_position: f64) -> Result<(), FernError> {
        let db = self.db.lock().unwrap();
        let mut project = db
            .get_project(&id)
            .map_err(|e| FernError::DatabaseError(e.to_string()))?
            .ok_or_else(|| FernError::DatabaseError("Project not found".to_string()))?;
        project.position = new_position;
        db.update_project(&project)
            .map(|_| ())
            .map_err(|e| FernError::DatabaseError(e.to_string()))
    }

    // =========================================================================
    // Task API
    // =========================================================================
    pub fn create_task(&self, mut task: Task) -> Result<(), FernError> {
        let db = self.db.lock().unwrap();
        if let Some(pid) = &task.project_id {
            if let Some(p) = db
                .get_project(pid)
                .map_err(|e| FernError::DatabaseError(e.to_string()))?
            {
                task.area_id = p.area_id;
            }
        }
        db.create_task(&task)
            .map_err(|e| FernError::DatabaseError(e.to_string()))?;
        Ok(())
    }

    pub fn update_task(&self, mut task: Task) -> Result<(), FernError> {
        let db = self.db.lock().unwrap();
        if let Some(pid) = &task.project_id {
            if let Some(p) = db
                .get_project(pid)
                .map_err(|e| FernError::DatabaseError(e.to_string()))?
            {
                task.area_id = p.area_id;
            }
        }
        db.update_task(&task)
            .map(|_| ())
            .map_err(|e| FernError::DatabaseError(e.to_string()))?;
        Ok(())
    }

    pub fn update_task_position(&self, id: String, new_position: f64) -> Result<(), FernError> {
        let db = self.db.lock().unwrap();
        let mut task = db
            .get_task(&id)
            .map_err(|e| FernError::DatabaseError(e.to_string()))?
            .ok_or_else(|| FernError::DatabaseError("Task not found".to_string()))?;
        task.position = new_position;
        db.update_task(&task)
            .map(|_| ())
            .map_err(|e| FernError::DatabaseError(e.to_string()))
    }

    pub fn get_inbox_tasks(&self) -> Result<Vec<Task>, FernError> {
        self.db
            .lock()
            .unwrap()
            .get_inbox_tasks()
            .map_err(|e| FernError::DatabaseError(e.to_string()))
    }
    pub fn get_today_tasks(&self) -> Result<Vec<Task>, FernError> {
        self.db
            .lock()
            .unwrap()
            .get_today_tasks()
            .map_err(|e| FernError::DatabaseError(e.to_string()))
    }
    pub fn get_anytime_tasks(&self) -> Result<Vec<Task>, FernError> {
        self.db
            .lock()
            .unwrap()
            .get_anytime_tasks()
            .map_err(|e| FernError::DatabaseError(e.to_string()))
    }
    pub fn get_upcoming_tasks(&self) -> Result<Vec<Task>, FernError> {
        self.db
            .lock()
            .unwrap()
            .get_upcoming_tasks()
            .map_err(|e| FernError::DatabaseError(e.to_string()))
    }
    pub fn get_someday_tasks(&self) -> Result<Vec<Task>, FernError> {
        self.db
            .lock()
            .unwrap()
            .get_someday_tasks()
            .map_err(|e| FernError::DatabaseError(e.to_string()))
    }
    pub fn get_logbook_tasks(&self) -> Result<Vec<Task>, FernError> {
        self.db
            .lock()
            .unwrap()
            .get_logbook_tasks()
            .map_err(|e| FernError::DatabaseError(e.to_string()))
    }
    pub fn complete_task(&self, id: String) -> Result<(), FernError> {
        self.db
            .lock()
            .unwrap()
            .complete_task(&id)
            .map_err(|e| FernError::DatabaseError(e.to_string()))?;
        Ok(())
    }
    pub fn trash_task(&self, id: String) -> Result<(), FernError> {
        self.db
            .lock()
            .unwrap()
            .trash_task(&id)
            .map_err(|e| FernError::DatabaseError(e.to_string()))?;
        Ok(())
    }
    pub fn delete_task(&self, id: String) -> Result<(), FernError> {
        self.db
            .lock()
            .unwrap()
            .delete_task(&id)
            .map_err(|e| FernError::DatabaseError(e.to_string()))?;
        Ok(())
    }
    pub fn restore_task(&self, id: String) -> Result<(), FernError> {
        self.db
            .lock()
            .unwrap()
            .restore_task(&id)
            .map_err(|e| FernError::DatabaseError(e.to_string()))?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
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
