

const AREA_SELECT: &str = "SELECT id, title, notes, is_archived, position FROM areas";



impl Database {
    /// Inserts a new Area.
    pub fn create_area(&self, area: &Area) -> SqlResult<usize> {
        self.conn.execute(
            "INSERT INTO areas (id, title, notes, is_archived, position) VALUES (?1, ?2, ?3, ?4, ?5)",
            params![area.id, area.title, area.notes, area.is_archived as i32, area.position],
        )
    }

    /// Returns a single Area by ID, or `None` if not found.
    pub fn get_area(&self, id: &str) -> SqlResult<Option<Area>> {
        let mut stmt = self
            .conn
            .prepare(&format!("{} WHERE id = ?1", AREA_SELECT))?;
        let mut rows = stmt.query_map(params![id], map_area_row)?;

        rows.next().transpose()
    }

    /// Returns all non-archived areas — use this for the sidebar.
    pub fn get_active_areas(&self) -> SqlResult<Vec<Area>> {
        let mut stmt = self
            .conn
            .prepare("SELECT id, title, notes, is_archived, position FROM areas WHERE is_archived = 0 ORDER BY position ASC")?;
        let rows = stmt
            .query_map([], |row| {
                Ok(Area {
                    id: row.get(0)?,
                    title: row.get(1)?,
                    notes: row.get(2)?,
                    is_archived: row.get::<_, i32>(3)? != 0,
                    position: row.get(4)?,
                })
            })?
            .collect();
        rows
    }

    /// Returns every area, including archived ones — use for settings screens.
    pub fn get_all_areas(&self) -> SqlResult<Vec<Area>> {
        let mut stmt = self
            .conn
            .prepare(&format!("{} ORDER BY position ASC", AREA_SELECT))?;
        let rows = stmt.query_map([], map_area_row)?.collect();
        rows
    }

    /// Updates the title and notes of an existing Area.
    /// Returns the number of rows affected (0 if the ID does not exist).
    pub fn update_area(&self, area: &Area) -> SqlResult<usize> {
        self.conn.execute(
            "UPDATE areas SET title = ?1, notes = ?2, position = ?4 WHERE id = ?3",
            params![area.title, area.notes, area.id, area.position],
        )
    }

    /// Hides an Area from the sidebar without deleting any data.
    pub fn archive_area(&self, id: &str) -> SqlResult<usize> {
        self.conn.execute(
            "UPDATE areas SET is_archived = 1 WHERE id = ?1",
            params![id],
        )
    }

    /// Restores an archived Area to the sidebar.
    pub fn unarchive_area(&self, id: &str) -> SqlResult<usize> {
        self.conn.execute(
            "UPDATE areas SET is_archived = 0 WHERE id = ?1",
            params![id],
        )
    }

    /// Hard-deletes an Area. Prefer `archive_area` in most cases — a hard
    /// delete will also cascade-orphan any child projects and tasks if FK
    /// constraints are not enforced at call time.
    pub fn delete_area(&self, id: &str) -> SqlResult<usize> {
        self.conn
            .execute("DELETE FROM tasks WHERE area_id = ?1", params![id])?;
        self.conn
            .execute("DELETE FROM projects WHERE area_id = ?1", params![id])?;
        self.conn
            .execute("DELETE FROM areas WHERE id = ?1", params![id])
    }
}

fn map_area_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<Area> {
    Ok(Area {
        id: row.get(0)?,
        title: row.get(1)?,
        notes: row.get(2)?,
        is_archived: row.get::<_, i32>(3)? != 0,
        position: row.get(4)?,
    })
}

#[cfg(test)]
mod area_tests {
    use super::*;
    
    use crate::models::*;
    use chrono::{Local, NaiveDate, NaiveTime};

    pub fn setup() -> Database {
        Database::new_in_memory().expect("failed to open in-memory database")
    }

    #[test]
    pub fn test_create_and_retrieve_area() {
        let db = setup();
        let area = Area::new("Work");
        db.create_area(&area).unwrap();
        assert_eq!(db.get_area(&area.id).unwrap(), Some(area));
    }

    #[test]
    pub fn test_get_area_returns_none_for_unknown_id() {
        let db = setup();
        assert!(db.get_area("ghost").unwrap().is_none());
    }

    #[test]
    pub fn test_get_active_areas_excludes_archived() {
        let db = setup();
        let a1 = Area::new("Work");
        let mut a2 = Area::new("Old client");
        a2.is_archived = true;
        db.create_area(&a1).unwrap();
        db.create_area(&a2).unwrap();

        let active = db.get_active_areas().unwrap();
        assert_eq!(active.len(), 1);
        assert_eq!(active[0].title, "Work");
    }

    #[test]
    pub fn test_get_all_areas_includes_archived() {
        let db = setup();
        let a1 = Area::new("Work");
        let mut a2 = Area::new("Old");
        a2.is_archived = true;
        db.create_area(&a1).unwrap();
        db.create_area(&a2).unwrap();
        assert_eq!(db.get_all_areas().unwrap().len(), 2);
    }

    #[test]
    pub fn test_update_area() {
        let db = setup();
        let mut area = Area::new("Work");
        db.create_area(&area).unwrap();
        area.title = "Pro Work".to_string();
        area.notes = "Updated".to_string();
        assert_eq!(db.update_area(&area).unwrap(), 1);
        let got = db.get_area(&area.id).unwrap().unwrap();
        assert_eq!(got.title, "Pro Work");
        assert_eq!(got.notes, "Updated");
    }

    #[test]
    pub fn test_archive_and_unarchive_area() {
        let db = setup();
        let area = Area::new("Old client");
        db.create_area(&area).unwrap();

        db.archive_area(&area.id).unwrap();
        assert!(db.get_area(&area.id).unwrap().unwrap().is_archived);
        assert_eq!(db.get_active_areas().unwrap().len(), 0);

        db.unarchive_area(&area.id).unwrap();
        assert!(!db.get_area(&area.id).unwrap().unwrap().is_archived);
        assert_eq!(db.get_active_areas().unwrap().len(), 1);
    }

    #[test]
    pub fn test_delete_area() {
        let db = setup();
        let area = Area::new("Temp");
        db.create_area(&area).unwrap();
        db.delete_area(&area.id).unwrap();
        assert!(db.get_area(&area.id).unwrap().is_none());
    }
}
