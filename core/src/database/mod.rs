use rusqlite::params;
use crate::models::*;
use rusqlite::{Connection, Result as SqlResult};

pub struct Database {
    pub(crate) conn: Connection,
}

impl Database {
    pub fn new(path: &str) -> SqlResult<Self> {
        let conn = Connection::open(path)?;
        let db = Database { conn };
        db.initialize_schema()?;
        Ok(db)
    }

    pub fn new_in_memory() -> SqlResult<Self> {
        let conn = Connection::open_in_memory()?;
        let db = Database { conn };
        db.initialize_schema()?;
        Ok(db)
    }

    fn initialize_schema(&self) -> SqlResult<()> {
        self.conn.execute_batch(
            "
            PRAGMA journal_mode = WAL;
            PRAGMA foreign_keys = ON;

            CREATE TABLE IF NOT EXISTS areas (
                id          TEXT    PRIMARY KEY NOT NULL,
                title       TEXT    NOT NULL,
                notes       TEXT    NOT NULL DEFAULT '',
                is_archived INTEGER NOT NULL DEFAULT 0,
                position    REAL    NOT NULL DEFAULT 0.0
            );

            CREATE TABLE IF NOT EXISTS projects (
                id             TEXT    PRIMARY KEY NOT NULL,
                area_id        TEXT    REFERENCES areas(id),
                title          TEXT    NOT NULL,
                notes          TEXT    NOT NULL DEFAULT '',
                scheduled_date TEXT,
                deadline       TEXT,
                status         TEXT    NOT NULL DEFAULT 'Todo',
                is_trashed     INTEGER NOT NULL DEFAULT 0,
                position       REAL    NOT NULL DEFAULT 0.0
            );

            CREATE TABLE IF NOT EXISTS tasks (
                id             TEXT    PRIMARY KEY NOT NULL,
                project_id     TEXT    REFERENCES projects(id),
                area_id        TEXT    REFERENCES areas(id),
                title          TEXT    NOT NULL,
                notes          TEXT    NOT NULL DEFAULT '',
                scheduled_date TEXT,
                deadline       TEXT,
                estimated_time INTEGER,
                spent_time     INTEGER,
                status         TEXT    NOT NULL DEFAULT 'Todo',
                is_trashed     INTEGER NOT NULL DEFAULT 0,
                position       REAL    NOT NULL DEFAULT 0.0
            );

            CREATE INDEX IF NOT EXISTS idx_tasks_status         ON tasks(status);
            CREATE INDEX IF NOT EXISTS idx_tasks_is_trashed     ON tasks(is_trashed);
            CREATE INDEX IF NOT EXISTS idx_tasks_scheduled_date ON tasks(scheduled_date);
            CREATE INDEX IF NOT EXISTS idx_tasks_project_id     ON tasks(project_id);
            CREATE INDEX IF NOT EXISTS idx_tasks_area_id        ON tasks(area_id);
            CREATE INDEX IF NOT EXISTS idx_projects_status      ON projects(status);
            CREATE INDEX IF NOT EXISTS idx_projects_is_trashed  ON projects(is_trashed);
            CREATE INDEX IF NOT EXISTS idx_projects_area_id     ON projects(area_id);
        ",
        )?;

        let _ = self.conn.execute("ALTER TABLE areas ADD COLUMN position REAL NOT NULL DEFAULT 0.0", []);
        let _ = self.conn.execute("ALTER TABLE projects ADD COLUMN position REAL NOT NULL DEFAULT 0.0", []);
        let _ = self.conn.execute("ALTER TABLE tasks ADD COLUMN position REAL NOT NULL DEFAULT 0.0", []);
        Ok(())
    }
}

#[cfg(test)]
mod database_tests {
    use super::*;
    #[test]
    fn test_schema_initializes_without_error() {
        let _db = Database::new_in_memory().unwrap();
    }
}

include!("area_repo.rs");
include!("project_repo.rs");
include!("task_repo.rs");
