#[uniffi::export]
impl FernAPI {
    pub fn get_all_tasks(&self) -> Result<Vec<Task>, FernError> {
        self.db
            .lock()
            .unwrap()
            .get_all_tasks()
            .map_err(|e| FernError::DatabaseError(e.to_string()))
    }
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
