use rusqlite::{params, Connection, Result as SqlResult};

use crate::models::{Area, Project, ProjectStatus, Task, TaskStatus};

/// Wraps a SQLite connection and exposes the fern database operations.
pub struct Database {
    conn: Connection,
}

impl Database {
    /// Opens (or creates) a SQLite database at the given path, then applies
    /// the schema migration so all tables are ready to use.
    pub fn new(path: &str) -> SqlResult<Self> {
        let conn = Connection::open(path)?;
        let db = Database { conn };
        db.initialize_schema()?;
        Ok(db)
    }

    /// Opens an in-memory database. Useful for tests.
    pub fn new_in_memory() -> SqlResult<Self> {
        let conn = Connection::open_in_memory()?;
        let db = Database { conn };
        db.initialize_schema()?;
        Ok(db)
    }

    /// Creates all tables if they do not already exist.
    /// Enabling WAL mode and foreign-key enforcement on every connection.
    fn initialize_schema(&self) -> SqlResult<()> {
        self.conn.execute_batch(
            "
            PRAGMA journal_mode=WAL;
            PRAGMA foreign_keys=ON;

            CREATE TABLE IF NOT EXISTS areas (
                id    TEXT PRIMARY KEY NOT NULL,
                title TEXT NOT NULL,
                notes TEXT NOT NULL DEFAULT ''
            );

            CREATE TABLE IF NOT EXISTS projects (
                id       TEXT PRIMARY KEY NOT NULL,
                area_id  TEXT REFERENCES areas(id),
                title    TEXT NOT NULL,
                notes    TEXT NOT NULL DEFAULT '',
                deadline TEXT,
                status   TEXT NOT NULL DEFAULT 'Active'
            );

            CREATE TABLE IF NOT EXISTS tasks (
                id             TEXT PRIMARY KEY NOT NULL,
                project_id     TEXT REFERENCES projects(id),
                area_id        TEXT REFERENCES areas(id),
                title          TEXT NOT NULL,
                notes          TEXT NOT NULL DEFAULT '',
                start_date     TEXT,
                deadline       TEXT,
                estimated_time INTEGER,
                spent_time     INTEGER,
                status         TEXT NOT NULL DEFAULT 'Inbox'
            );
        ",
        )
    }

    // =========================================================================
    // Area CRUD
    // =========================================================================

    /// Inserts a new Area into the database.
    pub fn create_area(&self, area: &Area) -> SqlResult<()> {
        self.conn.execute(
            "INSERT INTO areas (id, title, notes) VALUES (?1, ?2, ?3)",
            params![area.id, area.title, area.notes],
        )?;
        Ok(())
    }

    /// Returns all Areas.
    pub fn get_all_areas(&self) -> SqlResult<Vec<Area>> {
        let mut stmt = self.conn.prepare("SELECT id, title, notes FROM areas")?;
        let rows = stmt.query_map([], |row| {
            Ok(Area {
                id: row.get(0)?,
                title: row.get(1)?,
                notes: row.get(2)?,
            })
        })?;
        rows.collect()
    }

    /// Returns a single Area by its ID.
    pub fn get_area(&self, id: &str) -> SqlResult<Option<Area>> {
        let mut stmt = self
            .conn
            .prepare("SELECT id, title, notes FROM areas WHERE id = ?1")?;
        let mut rows = stmt.query_map(params![id], |row| {
            Ok(Area {
                id: row.get(0)?,
                title: row.get(1)?,
                notes: row.get(2)?,
            })
        })?;
        rows.next().transpose()
    }

    /// Updates the title and notes of an existing Area.
    pub fn update_area(&self, area: &Area) -> SqlResult<usize> {
        self.conn.execute(
            "UPDATE areas SET title = ?1, notes = ?2 WHERE id = ?3",
            params![area.title, area.notes, area.id],
        )
    }

    /// Hard-deletes an Area (use with caution; prefer updating status on
    /// child projects to 'Trash' for soft-deletes).
    pub fn delete_area(&self, id: &str) -> SqlResult<usize> {
        self.conn
            .execute("DELETE FROM areas WHERE id = ?1", params![id])
    }

    // =========================================================================
    // Project CRUD
    // =========================================================================

    /// Inserts a new Project into the database.
    pub fn create_project(&self, project: &Project) -> SqlResult<()> {
        self.conn.execute(
            "INSERT INTO projects (id, area_id, title, notes, deadline, status)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            params![
                project.id,
                project.area_id,
                project.title,
                project.notes,
                project.deadline.map(|d| d.to_string()),
                project.status.as_str(),
            ],
        )?;
        Ok(())
    }

    /// Returns all Projects.
    pub fn get_all_projects(&self) -> SqlResult<Vec<Project>> {
        let mut stmt = self
            .conn
            .prepare("SELECT id, area_id, title, notes, deadline, status FROM projects")?;
        let rows = stmt.query_map([], |row| {
            let deadline_str: Option<String> = row.get(4)?;
            let status_str: String = row.get(5)?;
            Ok((
                row.get(0)?,
                row.get(1)?,
                row.get(2)?,
                row.get(3)?,
                deadline_str,
                status_str,
            ))
        })?;

        let mut projects = Vec::new();
        for row in rows {
            let (id, area_id, title, notes, deadline_str, status_str) = row?;
            let deadline = deadline_str
                .as_deref()
                .map(|s| s.parse::<chrono::NaiveDate>())
                .transpose()
                .map_err(|e| {
                    rusqlite::Error::FromSqlConversionFailure(
                        4,
                        rusqlite::types::Type::Text,
                        Box::new(e),
                    )
                })?;
            let status = status_str.parse::<ProjectStatus>().map_err(|e| {
                rusqlite::Error::FromSqlConversionFailure(
                    5,
                    rusqlite::types::Type::Text,
                    Box::new(ParseError(e)),
                )
            })?;
            projects.push(Project {
                id,
                area_id,
                title,
                notes,
                deadline,
                status,
            });
        }
        Ok(projects)
    }

    /// Returns a single Project by its ID.
    pub fn get_project(&self, id: &str) -> SqlResult<Option<Project>> {
        let mut stmt = self.conn.prepare(
            "SELECT id, area_id, title, notes, deadline, status FROM projects WHERE id = ?1",
        )?;
        let mut rows = stmt.query_map(params![id], |row| {
            let deadline_str: Option<String> = row.get(4)?;
            let status_str: String = row.get(5)?;
            Ok((
                row.get(0)?,
                row.get(1)?,
                row.get(2)?,
                row.get(3)?,
                deadline_str,
                status_str,
            ))
        })?;

        match rows.next() {
            None => Ok(None),
            Some(row) => {
                let (id, area_id, title, notes, deadline_str, status_str) = row?;
                let deadline = deadline_str
                    .as_deref()
                    .map(|s| s.parse::<chrono::NaiveDate>())
                    .transpose()
                    .map_err(|e| {
                        rusqlite::Error::FromSqlConversionFailure(
                            4,
                            rusqlite::types::Type::Text,
                            Box::new(e),
                        )
                    })?;
                let status = status_str.parse::<ProjectStatus>().map_err(|e| {
                    rusqlite::Error::FromSqlConversionFailure(
                        5,
                        rusqlite::types::Type::Text,
                        Box::new(ParseError(e)),
                    )
                })?;
                Ok(Some(Project {
                    id,
                    area_id,
                    title,
                    notes,
                    deadline,
                    status,
                }))
            }
        }
    }

    /// Updates all mutable fields of an existing Project.
    pub fn update_project(&self, project: &Project) -> SqlResult<usize> {
        self.conn.execute(
            "UPDATE projects SET area_id = ?1, title = ?2, notes = ?3,
             deadline = ?4, status = ?5 WHERE id = ?6",
            params![
                project.area_id,
                project.title,
                project.notes,
                project.deadline.map(|d| d.to_string()),
                project.status.as_str(),
                project.id,
            ],
        )
    }

    /// Soft-deletes a Project by moving it to Trash.
    pub fn trash_project(&self, id: &str) -> SqlResult<usize> {
        self.conn.execute(
            "UPDATE projects SET status = 'Trash' WHERE id = ?1",
            params![id],
        )
    }

    // =========================================================================
    // Task CRUD
    // =========================================================================

    /// Inserts a new Task into the database.
    pub fn create_task(&self, task: &Task) -> SqlResult<()> {
        self.conn.execute(
            "INSERT INTO tasks (id, project_id, area_id, title, notes,
             start_date, deadline, estimated_time, spent_time, status)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)",
            params![
                task.id,
                task.project_id,
                task.area_id,
                task.title,
                task.notes,
                task.start_date.map(|d| d.to_string()),
                task.deadline.map(|d| d.to_string()),
                task.estimated_time,
                task.spent_time,
                task.status.as_str(),
            ],
        )?;
        Ok(())
    }

    /// Returns all Tasks.
    pub fn get_all_tasks(&self) -> SqlResult<Vec<Task>> {
        let mut stmt = self.conn.prepare(
            "SELECT id, project_id, area_id, title, notes,
             start_date, deadline, estimated_time, spent_time, status
             FROM tasks",
        )?;
        let rows = stmt.query_map([], |row| {
            Ok((
                row.get::<_, String>(0)?,
                row.get::<_, Option<String>>(1)?,
                row.get::<_, Option<String>>(2)?,
                row.get::<_, String>(3)?,
                row.get::<_, String>(4)?,
                row.get::<_, Option<String>>(5)?,
                row.get::<_, Option<String>>(6)?,
                row.get::<_, Option<i64>>(7)?,
                row.get::<_, Option<i64>>(8)?,
                row.get::<_, String>(9)?,
            ))
        })?;

        let mut tasks = Vec::new();
        for row in rows {
            let (
                id,
                project_id,
                area_id,
                title,
                notes,
                start_str,
                deadline_str,
                estimated_time,
                spent_time,
                status_str,
            ) = row?;
            tasks.push(parse_task_row(
                id,
                project_id,
                area_id,
                title,
                notes,
                start_str,
                deadline_str,
                estimated_time,
                spent_time,
                status_str,
            )?);
        }
        Ok(tasks)
    }

    /// Returns a single Task by its ID.
    pub fn get_task(&self, id: &str) -> SqlResult<Option<Task>> {
        let mut stmt = self.conn.prepare(
            "SELECT id, project_id, area_id, title, notes,
             start_date, deadline, estimated_time, spent_time, status
             FROM tasks WHERE id = ?1",
        )?;
        let mut rows = stmt.query_map(params![id], |row| {
            Ok((
                row.get::<_, String>(0)?,
                row.get::<_, Option<String>>(1)?,
                row.get::<_, Option<String>>(2)?,
                row.get::<_, String>(3)?,
                row.get::<_, String>(4)?,
                row.get::<_, Option<String>>(5)?,
                row.get::<_, Option<String>>(6)?,
                row.get::<_, Option<i64>>(7)?,
                row.get::<_, Option<i64>>(8)?,
                row.get::<_, String>(9)?,
            ))
        })?;

        match rows.next() {
            None => Ok(None),
            Some(row) => {
                let (
                    id,
                    project_id,
                    area_id,
                    title,
                    notes,
                    start_str,
                    deadline_str,
                    estimated_time,
                    spent_time,
                    status_str,
                ) = row?;
                Ok(Some(parse_task_row(
                    id,
                    project_id,
                    area_id,
                    title,
                    notes,
                    start_str,
                    deadline_str,
                    estimated_time,
                    spent_time,
                    status_str,
                )?))
            }
        }
    }

    /// Returns all Tasks for a given status (e.g., Inbox, Active).
    pub fn get_tasks_by_status(&self, status: &TaskStatus) -> SqlResult<Vec<Task>> {
        let mut stmt = self.conn.prepare(
            "SELECT id, project_id, area_id, title, notes,
             start_date, deadline, estimated_time, spent_time, status
             FROM tasks WHERE status = ?1",
        )?;
        let rows = stmt.query_map(params![status.as_str()], |row| {
            Ok((
                row.get::<_, String>(0)?,
                row.get::<_, Option<String>>(1)?,
                row.get::<_, Option<String>>(2)?,
                row.get::<_, String>(3)?,
                row.get::<_, String>(4)?,
                row.get::<_, Option<String>>(5)?,
                row.get::<_, Option<String>>(6)?,
                row.get::<_, Option<i64>>(7)?,
                row.get::<_, Option<i64>>(8)?,
                row.get::<_, String>(9)?,
            ))
        })?;

        let mut tasks = Vec::new();
        for row in rows {
            let (
                id,
                project_id,
                area_id,
                title,
                notes,
                start_str,
                deadline_str,
                estimated_time,
                spent_time,
                status_str,
            ) = row?;
            tasks.push(parse_task_row(
                id,
                project_id,
                area_id,
                title,
                notes,
                start_str,
                deadline_str,
                estimated_time,
                spent_time,
                status_str,
            )?);
        }
        Ok(tasks)
    }

    /// Updates all mutable fields of an existing Task.
    pub fn update_task(&self, task: &Task) -> SqlResult<usize> {
        self.conn.execute(
            "UPDATE tasks SET project_id = ?1, area_id = ?2, title = ?3,
             notes = ?4, start_date = ?5, deadline = ?6,
             estimated_time = ?7, spent_time = ?8, status = ?9
             WHERE id = ?10",
            params![
                task.project_id,
                task.area_id,
                task.title,
                task.notes,
                task.start_date.map(|d| d.to_string()),
                task.deadline.map(|d| d.to_string()),
                task.estimated_time,
                task.spent_time,
                task.status.as_str(),
                task.id,
            ],
        )
    }

    /// Soft-deletes a Task by moving it to Trash.
    pub fn trash_task(&self, id: &str) -> SqlResult<usize> {
        self.conn.execute(
            "UPDATE tasks SET status = 'Trash' WHERE id = ?1",
            params![id],
        )
    }
}

// =========================================================================
// Private helpers
// =========================================================================

/// Parses a full task row from raw SQL column values.
#[allow(clippy::too_many_arguments)]
fn parse_task_row(
    id: String,
    project_id: Option<String>,
    area_id: Option<String>,
    title: String,
    notes: String,
    start_str: Option<String>,
    deadline_str: Option<String>,
    estimated_time: Option<i64>,
    spent_time: Option<i64>,
    status_str: String,
) -> SqlResult<Task> {
    let start_date = start_str
        .as_deref()
        .map(|s| s.parse::<chrono::NaiveDate>())
        .transpose()
        .map_err(|e| {
            rusqlite::Error::FromSqlConversionFailure(5, rusqlite::types::Type::Text, Box::new(e))
        })?;
    let deadline = deadline_str
        .as_deref()
        .map(|s| s.parse::<chrono::NaiveDate>())
        .transpose()
        .map_err(|e| {
            rusqlite::Error::FromSqlConversionFailure(6, rusqlite::types::Type::Text, Box::new(e))
        })?;
    let status = status_str.parse::<TaskStatus>().map_err(|e| {
        rusqlite::Error::FromSqlConversionFailure(
            9,
            rusqlite::types::Type::Text,
            Box::new(ParseError(e)),
        )
    })?;
    Ok(Task {
        id,
        project_id,
        area_id,
        title,
        notes,
        start_date,
        deadline,
        estimated_time,
        spent_time,
        status,
    })
}

/// Newtype wrapper to make a `String` error implement `std::error::Error`,
/// which is required by `rusqlite::Error::FromSqlConversionFailure`.
#[derive(Debug)]
struct ParseError(String);

impl std::fmt::Display for ParseError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.0)
    }
}

impl std::error::Error for ParseError {}

// =========================================================================
// Tests
// =========================================================================

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::{Area, Project, Task, TaskStatus};
    use chrono::NaiveDate;

    fn setup() -> Database {
        Database::new_in_memory().expect("failed to open in-memory database")
    }

    // --- Schema ---

    #[test]
    fn test_schema_initializes_without_error() {
        // If setup() panics the test fails — no explicit assert needed.
        let _db = setup();
    }

    // --- Area CRUD ---

    #[test]
    fn test_create_and_retrieve_area() {
        let db = setup();
        let area = Area::new("Work");
        db.create_area(&area).expect("create_area failed");

        let retrieved = db.get_area(&area.id).expect("get_area failed");
        assert_eq!(retrieved, Some(area));
    }

    #[test]
    fn test_get_all_areas_returns_all_inserted() {
        let db = setup();
        let a1 = Area::new("Work");
        let a2 = Area::new("Personal");
        db.create_area(&a1).unwrap();
        db.create_area(&a2).unwrap();

        let all = db.get_all_areas().expect("get_all_areas failed");
        assert_eq!(all.len(), 2);
    }

    #[test]
    fn test_get_area_returns_none_for_unknown_id() {
        let db = setup();
        let result = db.get_area("non-existent-id").expect("get_area failed");
        assert!(result.is_none());
    }

    #[test]
    fn test_update_area() {
        let db = setup();
        let mut area = Area::new("Work");
        db.create_area(&area).unwrap();

        area.title = "Pro Work".to_string();
        area.notes = "Updated notes".to_string();
        let affected = db.update_area(&area).expect("update_area failed");
        assert_eq!(affected, 1);

        let retrieved = db.get_area(&area.id).unwrap().unwrap();
        assert_eq!(retrieved.title, "Pro Work");
        assert_eq!(retrieved.notes, "Updated notes");
    }

    #[test]
    fn test_delete_area() {
        let db = setup();
        let area = Area::new("Temp");
        db.create_area(&area).unwrap();
        db.delete_area(&area.id).expect("delete_area failed");

        let result = db.get_area(&area.id).unwrap();
        assert!(result.is_none());
    }

    // --- Project CRUD ---

    #[test]
    fn test_create_and_retrieve_project() {
        let db = setup();
        let project = Project::new("Launch Website");
        db.create_project(&project).expect("create_project failed");

        let retrieved = db.get_project(&project.id).expect("get_project failed");
        assert_eq!(retrieved, Some(project));
    }

    #[test]
    fn test_project_with_area_and_deadline() {
        let db = setup();
        let area = Area::new("Work");
        db.create_area(&area).unwrap();

        let mut project = Project::new("Q3 Report");
        project.area_id = Some(area.id.clone());
        project.deadline = Some(NaiveDate::from_ymd_opt(2026, 9, 30).unwrap());
        db.create_project(&project).unwrap();

        let retrieved = db.get_project(&project.id).unwrap().unwrap();
        assert_eq!(retrieved.area_id, Some(area.id));
        assert_eq!(retrieved.deadline, project.deadline);
    }

    #[test]
    fn test_trash_project_sets_status_to_trash() {
        let db = setup();
        let project = Project::new("Old Project");
        db.create_project(&project).unwrap();

        db.trash_project(&project.id).expect("trash_project failed");

        let retrieved = db.get_project(&project.id).unwrap().unwrap();
        assert_eq!(retrieved.status, crate::models::ProjectStatus::Trash);
    }

    #[test]
    fn test_update_project() {
        let db = setup();
        let mut project = Project::new("Draft");
        db.create_project(&project).unwrap();

        project.title = "Published".to_string();
        project.status = crate::models::ProjectStatus::Logbook;
        db.update_project(&project).expect("update_project failed");

        let retrieved = db.get_project(&project.id).unwrap().unwrap();
        assert_eq!(retrieved.title, "Published");
        assert_eq!(retrieved.status, crate::models::ProjectStatus::Logbook);
    }

    // --- Task CRUD ---

    #[test]
    fn test_create_and_retrieve_task() {
        let db = setup();
        let task = Task::new("Buy groceries");
        db.create_task(&task).expect("create_task failed");

        let retrieved = db.get_task(&task.id).expect("get_task failed");
        assert_eq!(retrieved, Some(task));
    }

    #[test]
    fn test_task_with_all_optional_fields() {
        let db = setup();
        let mut task = Task::new("Deep work session");
        task.start_date = Some(NaiveDate::from_ymd_opt(2026, 6, 20).unwrap());
        task.deadline = Some(NaiveDate::from_ymd_opt(2026, 6, 21).unwrap());
        task.estimated_time = Some(90);
        task.spent_time = Some(45);
        task.status = TaskStatus::Active;
        db.create_task(&task).unwrap();

        let retrieved = db.get_task(&task.id).unwrap().unwrap();
        assert_eq!(retrieved, task);
    }

    #[test]
    fn test_get_tasks_by_status_inbox() {
        let db = setup();
        let inbox_task = Task::new("Inbox item");
        let mut active_task = Task::new("Active item");
        active_task.status = TaskStatus::Active;
        db.create_task(&inbox_task).unwrap();
        db.create_task(&active_task).unwrap();

        let inbox = db.get_tasks_by_status(&TaskStatus::Inbox).expect("failed");
        assert_eq!(inbox.len(), 1);
        assert_eq!(inbox[0].title, "Inbox item");
    }

    #[test]
    fn test_trash_task_sets_status_to_trash() {
        let db = setup();
        let task = Task::new("Old task");
        db.create_task(&task).unwrap();

        db.trash_task(&task.id).expect("trash_task failed");

        let retrieved = db.get_task(&task.id).unwrap().unwrap();
        assert_eq!(retrieved.status, TaskStatus::Trash);
    }

    #[test]
    fn test_update_task() {
        let db = setup();
        let mut task = Task::new("Write draft");
        db.create_task(&task).unwrap();

        task.notes = "First draft done".to_string();
        task.spent_time = Some(60);
        task.status = TaskStatus::Logbook;
        db.update_task(&task).expect("update_task failed");

        let retrieved = db.get_task(&task.id).unwrap().unwrap();
        assert_eq!(retrieved.notes, "First draft done");
        assert_eq!(retrieved.spent_time, Some(60));
        assert_eq!(retrieved.status, TaskStatus::Logbook);
    }

    #[test]
    fn test_get_all_tasks_returns_all_inserted() {
        let db = setup();
        db.create_task(&Task::new("Task A")).unwrap();
        db.create_task(&Task::new("Task B")).unwrap();
        db.create_task(&Task::new("Task C")).unwrap();

        let tasks = db.get_all_tasks().expect("get_all_tasks failed");
        assert_eq!(tasks.len(), 3);
    }
}
