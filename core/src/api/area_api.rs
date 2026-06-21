#[uniffi::export]
impl FernAPI {
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
}
