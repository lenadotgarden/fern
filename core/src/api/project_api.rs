#[uniffi::export]
impl FernAPI {
    pub fn get_all_projects(&self) -> Result<Vec<Project>, FernError> {
        self.db
            .lock()
            .unwrap()
            .get_all_projects()
            .map_err(|e| FernError::DatabaseError(e.to_string()))
    }
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
}
