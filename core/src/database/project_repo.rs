

const PROJECT_SELECT: &str = "SELECT id, area_id, title, notes, scheduled_date, deadline, status, is_trashed, position FROM projects";



impl Database {
    /// Inserts a new Project.
    pub fn create_project(&self, project: &Project) -> SqlResult<usize> {
        self.conn.execute(
            "INSERT INTO projects (id, area_id, title, notes, scheduled_date, deadline, status, is_trashed, position)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)",
            params![
                project.id,
                project.area_id,
                project.title,
                project.notes,
                project.scheduled_date.as_ref().map(|d| d.to_db_string()),
                project.deadline.map(|d| d.to_string()),
                project.status.as_str(),
                project.is_trashed as i32,
                project.position,
            ],
        )
    }

    /// Returns a single Project by ID, or `None` if not found.
    pub fn get_project(&self, id: &str) -> SqlResult<Option<Project>> {
        let mut stmt = self
            .conn
            .prepare(&format!("{} WHERE id = ?1", PROJECT_SELECT))?;
        let mut rows = stmt.query_map(params![id], map_project_row)?;

        rows.next().transpose()
    }

    /// Returns every project (all statuses, including trashed).
    pub fn get_all_projects(&self) -> SqlResult<Vec<Project>> {
        let mut stmt = self
            .conn
            .prepare(&format!("{} ORDER BY position ASC", PROJECT_SELECT))?;
        let rows = stmt.query_map([], map_project_row)?.collect();
        rows
    }

    /// Updates all mutable fields of an existing Project.
    /// Returns the number of rows affected (0 if the ID does not exist).
    pub fn update_project(&self, project: &Project) -> SqlResult<usize> {
        self.conn.execute(
            "UPDATE projects SET area_id = ?1, title = ?2, notes = ?3,
             scheduled_date = ?4, deadline = ?5, status = ?6, is_trashed = ?7, position = ?9
             WHERE id = ?8",
            params![
                project.area_id,
                project.title,
                project.notes,
                project.scheduled_date.as_ref().map(|d| d.to_db_string()),
                project.deadline.map(|d| d.to_string()),
                project.status.as_str(),
                project.is_trashed as i32,
                project.id,
                project.position
            ],
        )
    }

    /// Marks a Project as Done (moves it to the Logbook).
    pub fn complete_project(&self, id: &str) -> SqlResult<usize> {
        self.conn.execute(
            "UPDATE projects SET status = 'Done' WHERE id = ?1",
            params![id],
        )
    }

    /// Marks a Project as Cancelled (moves it to the Logbook).
    pub fn cancel_project(&self, id: &str) -> SqlResult<usize> {
        self.conn.execute(
            "UPDATE projects SET status = 'Cancelled' WHERE id = ?1",
            params![id],
        )
    }

    /// Soft-deletes a Project by moving it to Trash.
    /// Does NOT change the status — a Done project can also be in Trash.
    pub fn trash_project(&self, id: &str) -> SqlResult<usize> {
        self.conn.execute(
            "UPDATE tasks SET is_trashed = 1 WHERE project_id = ?1",
            params![id],
        )?;
        self.conn.execute(
            "UPDATE projects SET is_trashed = 1 WHERE id = ?1",
            params![id],
        )
    }

    /// Hard-deletes a Task.
    pub fn delete_task(&self, id: &str) -> SqlResult<usize> {
        self.conn
            .execute("DELETE FROM tasks WHERE id = ?1", params![id])
    }

    /// Hard-deletes a Project, cascading to delete all its tasks.
    pub fn delete_project(&self, id: &str) -> SqlResult<usize> {
        self.conn
            .execute("DELETE FROM projects WHERE id = ?1", params![id])
    }

    /// Recovers a trashed Project, making it visible again in its previous view.
    pub fn restore_project(&self, id: &str) -> SqlResult<usize> {
        self.conn.execute(
            "UPDATE tasks SET is_trashed = 0 WHERE project_id = ?1",
            params![id],
        )?;
        self.conn.execute(
            "UPDATE projects SET is_trashed = 0 WHERE id = ?1",
            params![id],
        )
    }

    // --- Project Views ---

    /// **Anytime** — Todo projects with no scheduled date, OR scheduled for today/past, not trashed.
    pub fn get_anytime_projects(&self) -> SqlResult<Vec<Project>> {
        let mut stmt = self.conn.prepare(&format!(
            "{} WHERE status = 'Todo' AND is_trashed = 0 \
             AND (scheduled_date IS NULL \
                  OR (scheduled_date != 'someday' \
                      AND SUBSTR(scheduled_date, 1, 10) <= DATE('now', 'localtime'))) \
             ORDER BY position ASC",
            PROJECT_SELECT
        ))?;
        let rows = stmt.query_map([], map_project_row)?.collect();
        rows
    }

    /// **Someday** — Todo projects deferred indefinitely, not trashed.
    pub fn get_someday_projects(&self) -> SqlResult<Vec<Project>> {
        let mut stmt = self.conn.prepare(&format!(
            "{} WHERE status = 'Todo' AND is_trashed = 0 AND scheduled_date = 'someday' ORDER BY position ASC",
            PROJECT_SELECT
        ))?;
        let rows = stmt.query_map([], map_project_row)?.collect();
        rows
    }

    /// **Logbook** — Done or Cancelled projects, not trashed.
    pub fn get_logbook_projects(&self) -> SqlResult<Vec<Project>> {
        let mut stmt = self.conn.prepare(&format!(
            "{} WHERE status IN ('Done', 'Cancelled') AND is_trashed = 0 ORDER BY position ASC",
            PROJECT_SELECT
        ))?;
        let rows = stmt.query_map([], map_project_row)?.collect();
        rows
    }

    /// **Trash** — soft-deleted projects.
    pub fn get_trashed_projects(&self) -> SqlResult<Vec<Project>> {
        let mut stmt = self.conn.prepare(&format!(
            "{} WHERE is_trashed = 1 ORDER BY position ASC",
            PROJECT_SELECT
        ))?;
        let rows = stmt.query_map([], map_project_row)?.collect();
        rows
    }

    pub fn map_project_row(row: &rusqlite::Row) -> SqlResult<Project> {
        Ok(Project {
            id: row.get(0)?,
            area_id: row.get(1)?,
            title: row.get(2)?,
            notes: row.get(3)?,
            scheduled_date: row
                .get::<_, Option<String>>(4)?
                .and_then(|s| ScheduledDate::from_db_string(&s).ok()),
            deadline: row
                .get::<_, Option<String>>(5)?
                .and_then(|s| chrono::NaiveDate::parse_from_str(&s, "%Y-%m-%d").ok()),
            status: row
                .get::<_, String>(6)?
                .parse()
                .unwrap_or(ProjectStatus::Todo),
            is_trashed: row.get::<_, i32>(7)? != 0,
            position: row.get(8)?,
        })
    }
}

fn map_project_row(row: &rusqlite::Row) -> SqlResult<Project> {
        Ok(Project {
            id: row.get(0)?,
            area_id: row.get(1)?,
            title: row.get(2)?,
            notes: row.get(3)?,
            scheduled_date: row
                .get::<_, Option<String>>(4)?
                .and_then(|s| ScheduledDate::from_db_string(&s).ok()),
            deadline: row
                .get::<_, Option<String>>(5)?
                .and_then(|s| chrono::NaiveDate::parse_from_str(&s, "%Y-%m-%d").ok()),
            status: row
                .get::<_, String>(6)?
                .parse()
                .unwrap_or(ProjectStatus::Todo),
            is_trashed: row.get::<_, i32>(7)? != 0,
            position: row.get(8)?,
        })
    }

#[cfg(test)]
mod project_tests {
    use super::*;
    
    use crate::models::*;
    use chrono::{Local, NaiveDate, NaiveTime};

    pub fn setup() -> Database {
        Database::new_in_memory().expect("failed to open in-memory database")
    }

    #[test]
    pub fn test_create_and_retrieve_project() {
        let db = setup();
        let p = Project::new("Launch website");
        db.create_project(&p).unwrap();
        assert_eq!(db.get_project(&p.id).unwrap(), Some(p));
    }

    #[test]
    pub fn test_get_project_returns_none_for_unknown_id() {
        let db = setup();
        assert!(db.get_project("ghost").unwrap().is_none());
    }

    #[test]
    pub fn test_project_with_area_deadline_and_scheduled_date() {
        let db = setup();
        let area = Area::new("Work");
        db.create_area(&area).unwrap();

        let mut p = Project::new("Q3 Report");
        p.area_id = Some(area.id.clone());
        p.deadline = Some(NaiveDate::from_ymd_opt(2026, 9, 30).unwrap());
        p.scheduled_date = Some(ScheduledDate::On {
            date: NaiveDate::from_ymd_opt(2026, 7, 1).unwrap(),
            time: None,
        });
        db.create_project(&p).unwrap();

        let got = db.get_project(&p.id).unwrap().unwrap();
        assert_eq!(got.area_id, Some(area.id));
        assert_eq!(got.deadline, p.deadline);
        assert_eq!(got.scheduled_date, p.scheduled_date);
    }

    #[test]
    pub fn test_complete_project_moves_to_logbook() {
        let db = setup();
        let p = Project::new("Done project");
        db.create_project(&p).unwrap();
        db.complete_project(&p.id).unwrap();

        let got = db.get_project(&p.id).unwrap().unwrap();
        assert_eq!(got.status, ProjectStatus::Done);

        // Must appear in logbook, not anytime
        assert_eq!(db.get_logbook_projects().unwrap().len(), 1);
        assert_eq!(db.get_anytime_projects().unwrap().len(), 0);
    }

    #[test]
    pub fn test_cancel_project_moves_to_logbook() {
        let db = setup();
        let p = Project::new("Cancelled project");
        db.create_project(&p).unwrap();
        db.cancel_project(&p.id).unwrap();

        assert_eq!(
            db.get_project(&p.id).unwrap().unwrap().status,
            ProjectStatus::Cancelled
        );
        assert_eq!(db.get_logbook_projects().unwrap().len(), 1);
    }

    #[test]
    pub fn test_trash_and_restore_project() {
        let db = setup();
        let p = Project::new("Draft");
        db.create_project(&p).unwrap();

        db.trash_project(&p.id).unwrap();
        assert!(db.get_project(&p.id).unwrap().unwrap().is_trashed);
        // Trashed project must NOT appear in anytime
        assert_eq!(db.get_anytime_projects().unwrap().len(), 0);
        assert_eq!(db.get_trashed_projects().unwrap().len(), 1);

        db.restore_project(&p.id).unwrap();
        assert!(!db.get_project(&p.id).unwrap().unwrap().is_trashed);
        assert_eq!(db.get_anytime_projects().unwrap().len(), 1);
        assert_eq!(db.get_trashed_projects().unwrap().len(), 0);
    }

    #[test]
    pub fn test_done_project_can_also_be_trashed() {
        // Status and is_trashed are independent. A Done project can be trashed
        // (it won't appear in Logbook anymore, only in Trash).
        let db = setup();
        let p = Project::new("Done then trashed");
        db.create_project(&p).unwrap();
        db.complete_project(&p.id).unwrap();
        db.trash_project(&p.id).unwrap();

        let got = db.get_project(&p.id).unwrap().unwrap();
        assert_eq!(got.status, ProjectStatus::Done);
        assert!(got.is_trashed);

        assert_eq!(db.get_logbook_projects().unwrap().len(), 0); // not in logbook
        assert_eq!(db.get_trashed_projects().unwrap().len(), 1); // in trash
    }

    // -------------------------------------------------------------------------
    // Project Views
    // -------------------------------------------------------------------------

    #[test]
    pub fn test_project_views_are_mutually_exclusive() {
        let db = setup();

        let p_anytime = Project::new("Active project");
        let mut p_today = Project::new("Today project");
        p_today.scheduled_date = Some(ScheduledDate::On {
            date: Local::now().date_naive(),
            time: None,
        });
        let mut p_someday = Project::new("Someday project");
        p_someday.scheduled_date = Some(ScheduledDate::Someday);
        let p_done = Project::new("Done project");

        db.create_project(&p_anytime).unwrap();
        db.create_project(&p_today).unwrap();
        db.create_project(&p_someday).unwrap();
        db.create_project(&p_done).unwrap();
        db.complete_project(&p_done.id).unwrap();

        // Anytime should include both the un-scheduled project AND the today project
        assert_eq!(db.get_anytime_projects().unwrap().len(), 2);
        assert_eq!(db.get_someday_projects().unwrap().len(), 1);
        assert_eq!(db.get_logbook_projects().unwrap().len(), 1);
        assert_eq!(db.get_trashed_projects().unwrap().len(), 0);
    }
}
