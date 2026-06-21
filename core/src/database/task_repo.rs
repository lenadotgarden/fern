

const TASK_SELECT: &str = "SELECT id, project_id, area_id, title, notes, scheduled_date, deadline, estimated_time, spent_time, status, is_trashed, position FROM tasks";



impl Database {
    /// Inserts a new Task.
    pub fn create_task(&self, task: &Task) -> SqlResult<()> {
        let scheduled_str = task.scheduled_date.as_ref().map(|d| d.to_db_string());
        let deadline_str = task.deadline.map(|d| d.to_string());
        self.conn.execute(
            "INSERT INTO tasks (
                id, project_id, area_id, title, notes, scheduled_date, deadline,
                estimated_time, spent_time, status, is_trashed, position
            ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12)",
            params![
                task.id,
                task.project_id,
                task.area_id,
                task.title,
                task.notes,
                scheduled_str,
                deadline_str,
                task.estimated_time,
                task.spent_time,
                task.status.as_str(),
                task.is_trashed as i32,
                task.position,
            ],
        )?;
        Ok(())
    }

    /// Returns a single Task by ID, or `None` if not found.
    pub fn get_task(&self, id: &str) -> SqlResult<Option<Task>> {
        let mut stmt = self
            .conn
            .prepare(&format!("{} WHERE id = ?1", TASK_SELECT))?;
        let mut rows = stmt.query_map(params![id], map_task_row)?;

        rows.next().transpose()
    }

    /// Returns every task (all statuses, including trashed).
    pub fn get_all_tasks(&self) -> SqlResult<Vec<Task>> {
        let mut stmt = self
            .conn
            .prepare(&format!("{} ORDER BY position ASC", TASK_SELECT))?;
        let rows = stmt.query_map([], map_task_row)?.collect();
        rows
    }

    pub fn update_tasks_area_for_project(
        &self,
        project_id: &str,
        area_id: Option<&String>,
    ) -> SqlResult<usize> {
        self.conn.execute(
            "UPDATE tasks SET area_id = ?1 WHERE project_id = ?2",
            params![area_id, project_id],
        )
    }

    /// Updates all mutable fields of an existing Task.
    /// Returns the number of rows affected (0 if the ID does not exist).
    pub fn update_task(&self, task: &Task) -> SqlResult<usize> {
        let scheduled_str = task.scheduled_date.as_ref().map(|d| d.to_db_string());
        let deadline_str = task.deadline.map(|d| d.to_string());
        self.conn.execute(
            "UPDATE tasks
             SET project_id = ?1,
                 area_id = ?2,
                 title = ?3,
                 notes = ?4,
                 scheduled_date = ?5,
                 deadline = ?6,
                 estimated_time = ?7,
                 spent_time = ?8,
                 status = ?9,
                 is_trashed = ?10,
                 position = ?11
             WHERE id = ?12",
            params![
                task.project_id,
                task.area_id,
                task.title,
                task.notes,
                scheduled_str,
                deadline_str,
                task.estimated_time,
                task.spent_time,
                task.status.as_str(),
                task.is_trashed as i32,
                task.position,
                task.id,
            ],
        )
    }

    /// Marks a Task as Done (moves it to the Logbook).
    pub fn complete_task(&self, id: &str) -> SqlResult<usize> {
        self.conn.execute(
            "UPDATE tasks SET status = 'Done' WHERE id = ?1",
            params![id],
        )
    }

    /// Marks a Task as Cancelled (moves it to the Logbook).
    pub fn cancel_task(&self, id: &str) -> SqlResult<usize> {
        self.conn.execute(
            "UPDATE tasks SET status = 'Cancelled' WHERE id = ?1",
            params![id],
        )
    }

    /// Soft-deletes a Task by moving it to Trash.
    /// Does NOT change the status — a Done task can also be in Trash.
    pub fn trash_task(&self, id: &str) -> SqlResult<usize> {
        self.conn
            .execute("UPDATE tasks SET is_trashed = 1 WHERE id = ?1", params![id])
    }

    /// Recovers a trashed Task, making it visible again in its previous view.
    pub fn restore_task(&self, id: &str) -> SqlResult<usize> {
        self.conn
            .execute("UPDATE tasks SET is_trashed = 0 WHERE id = ?1", params![id])
    }

    // --- Task Views ---

    /// **Inbox** — Unorganised Todo tasks: no project, no area, no scheduled
    /// date, not trashed. These move out of the Inbox the moment a project,
    /// area, or date is assigned.
    pub fn get_inbox_tasks(&self) -> SqlResult<Vec<Task>> {
        let mut stmt = self.conn.prepare(&format!(
            "{} WHERE status = 'Todo' AND is_trashed = 0 \
             AND project_id IS NULL AND area_id IS NULL AND scheduled_date IS NULL ORDER BY position ASC",
            TASK_SELECT
        ))?;
        let rows = stmt.query_map([], map_task_row)?.collect();
        rows
    }

    /// **Today** — Todo tasks scheduled for today's date, not trashed.
    /// Uses `SUBSTR(scheduled_date, 1, 10)` to safely handle both date-only
    /// ("2026-06-20") and datetime ("2026-06-20 14:30") formats.
    pub fn get_today_tasks(&self) -> SqlResult<Vec<Task>> {
        let mut stmt = self.conn.prepare(&format!(
            "{} WHERE status = 'Todo' AND is_trashed = 0 \
             AND scheduled_date IS NOT NULL \
             AND scheduled_date != 'someday' \
             AND SUBSTR(scheduled_date, 1, 10) = DATE('now', 'localtime') ORDER BY position ASC",
            TASK_SELECT
        ))?;
        let rows = stmt.query_map([], map_task_row)?.collect();
        rows
    }

    /// **Upcoming** — Todo tasks with a future scheduled date, not trashed.
    pub fn get_upcoming_tasks(&self) -> SqlResult<Vec<Task>> {
        let mut stmt = self.conn.prepare(&format!(
            "{} WHERE status = 'Todo' AND is_trashed = 0 \
             AND scheduled_date IS NOT NULL \
             AND scheduled_date != 'someday' \
             AND SUBSTR(scheduled_date, 1, 10) > DATE('now', 'localtime') ORDER BY position ASC",
            TASK_SELECT
        ))?;
        let rows = stmt.query_map([], map_task_row)?.collect();
        rows
    }

    /// **Anytime** — Todo tasks that you can work on right now.
    /// Includes tasks with no scheduled date (but assigned to a project/area),
    /// AND tasks scheduled for today or earlier.
    /// Excludes Someday, Upcoming (future), and unorganised Inbox tasks.
    pub fn get_anytime_tasks(&self) -> SqlResult<Vec<Task>> {
        let mut stmt = self.conn.prepare(&format!(
            "{} WHERE status = 'Todo' AND is_trashed = 0 \
             AND ( \
                 (scheduled_date IS NULL AND (project_id IS NOT NULL OR area_id IS NOT NULL)) \
                 OR \
                 (scheduled_date IS NOT NULL AND scheduled_date != 'someday' AND SUBSTR(scheduled_date, 1, 10) <= DATE('now', 'localtime')) \
             ) ORDER BY position ASC",
            TASK_SELECT
        ))?;
        let rows = stmt.query_map([], map_task_row)?.collect();
        rows
    }

    /// **Someday** — Todo tasks deferred indefinitely, not trashed.
    pub fn get_someday_tasks(&self) -> SqlResult<Vec<Task>> {
        let mut stmt = self.conn.prepare(&format!(
            "{} WHERE status = 'Todo' AND is_trashed = 0 AND scheduled_date = 'someday' ORDER BY position ASC",
            TASK_SELECT
        ))?;
        let rows = stmt.query_map([], map_task_row)?.collect();
        rows
    }

    /// **Logbook** — Done or Cancelled tasks, not trashed.
    /// A task completed while in the Inbox still appears here, correctly
    /// preserving its origin context (no project, no area).
    pub fn get_logbook_tasks(&self) -> SqlResult<Vec<Task>> {
        let mut stmt = self.conn.prepare(&format!(
            "{} WHERE status IN ('Done', 'Cancelled') AND is_trashed = 0 ORDER BY position ASC",
            TASK_SELECT
        ))?;
        let rows = stmt.query_map([], map_task_row)?.collect();
        rows
    }

    /// **Trash** — soft-deleted tasks.
    pub fn get_trashed_tasks(&self) -> SqlResult<Vec<Task>> {
        let mut stmt = self.conn.prepare(&format!(
            "{} WHERE is_trashed = 1 ORDER BY position ASC",
            TASK_SELECT
        ))?;
        let rows = stmt.query_map([], map_task_row)?.collect();
        rows
    }
}

fn map_task_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<Task> {
    let scheduled_str: Option<String> = row.get(5)?;
    let deadline_str: Option<String> = row.get(6)?;
    let status_str: String = row.get(9)?;

    let scheduled_date = scheduled_str
        .as_deref()
        .map(ScheduledDate::from_db_string)
        .transpose()
        .map_err(|e| {
            rusqlite::Error::FromSqlConversionFailure(
                5,
                rusqlite::types::Type::Text,
                Box::new(ParseError(e)),
            )
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
        id: row.get(0)?,
        project_id: row.get(1)?,
        area_id: row.get(2)?,
        title: row.get(3)?,
        notes: row.get(4)?,
        scheduled_date,
        deadline,
        estimated_time: row.get(7)?,
        spent_time: row.get(8)?,
        status,
        is_trashed: row.get::<_, i32>(10)? != 0,
        position: row.get(11)?,
    })
}

/// Wraps a `String` so it implements `std::error::Error`, as required by
/// `rusqlite::Error::FromSqlConversionFailure`.
#[derive(Debug)]
struct ParseError(String);

impl std::fmt::Display for ParseError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.0)
    }
}

impl std::error::Error for ParseError {}

#[cfg(test)]
mod task_tests {
    use super::*;
    
    use crate::models::*;
    use chrono::{Local, NaiveDate, NaiveTime};

    pub fn setup() -> Database {
        Database::new_in_memory().expect("failed to open in-memory database")
    }

    #[test]
    pub fn test_create_and_retrieve_task() {
        let db = setup();
        let t = Task::new("Buy groceries");
        db.create_task(&t).unwrap();
        assert_eq!(db.get_task(&t.id).unwrap(), Some(t));
    }

    #[test]
    pub fn test_get_task_returns_none_for_unknown_id() {
        let db = setup();
        assert!(db.get_task("ghost").unwrap().is_none());
    }

    #[test]
    pub fn test_task_with_all_optional_fields() {
        let db = setup();
        let mut t = Task::new("Deep work session");
        t.scheduled_date = Some(ScheduledDate::On {
            date: NaiveDate::from_ymd_opt(2026, 6, 25).unwrap(),
            time: Some(NaiveTime::from_hms_opt(9, 0, 0).unwrap()),
        });
        t.deadline = Some(NaiveDate::from_ymd_opt(2026, 6, 30).unwrap());
        t.estimated_time = Some(90);
        t.spent_time = Some(45);
        db.create_task(&t).unwrap();
        assert_eq!(db.get_task(&t.id).unwrap(), Some(t));
    }

    #[test]
    pub fn test_complete_task_moves_to_logbook() {
        let db = setup();
        let t = Task::new("Write report");
        db.create_task(&t).unwrap();
        db.complete_task(&t.id).unwrap();

        assert_eq!(
            db.get_task(&t.id).unwrap().unwrap().status,
            TaskStatus::Done
        );
        assert_eq!(db.get_logbook_tasks().unwrap().len(), 1);
        assert_eq!(db.get_inbox_tasks().unwrap().len(), 0);
    }

    #[test]
    pub fn test_cancel_task_moves_to_logbook() {
        let db = setup();
        let t = Task::new("Old idea");
        db.create_task(&t).unwrap();
        db.cancel_task(&t.id).unwrap();

        assert_eq!(
            db.get_task(&t.id).unwrap().unwrap().status,
            TaskStatus::Cancelled
        );
        assert_eq!(db.get_logbook_tasks().unwrap().len(), 1);
    }

    #[test]
    pub fn test_trash_and_restore_task() {
        let db = setup();
        let t = Task::new("Old task");
        db.create_task(&t).unwrap();

        db.trash_task(&t.id).unwrap();
        assert!(db.get_task(&t.id).unwrap().unwrap().is_trashed);
        assert_eq!(db.get_inbox_tasks().unwrap().len(), 0);
        assert_eq!(db.get_trashed_tasks().unwrap().len(), 1);

        db.restore_task(&t.id).unwrap();
        assert!(!db.get_task(&t.id).unwrap().unwrap().is_trashed);
        assert_eq!(db.get_inbox_tasks().unwrap().len(), 1);
        assert_eq!(db.get_trashed_tasks().unwrap().len(), 0);
    }

    #[test]
    pub fn test_done_task_can_also_be_trashed() {
        let db = setup();
        let t = Task::new("Done then trashed");
        db.create_task(&t).unwrap();
        db.complete_task(&t.id).unwrap();
        db.trash_task(&t.id).unwrap();

        let got = db.get_task(&t.id).unwrap().unwrap();
        assert_eq!(got.status, TaskStatus::Done);
        assert!(got.is_trashed);

        assert_eq!(db.get_logbook_tasks().unwrap().len(), 0); // not in logbook
        assert_eq!(db.get_trashed_tasks().unwrap().len(), 1); // in trash
    }

    // -------------------------------------------------------------------------
    // Task Views — Inbox, Today, Upcoming, Anytime, Someday
    // -------------------------------------------------------------------------

    #[test]
    pub fn test_inbox_contains_only_unorganised_todo_tasks() {
        let db = setup();

        let inbox = Task::new("Unclassified"); // no area, no project, no date

        let mut with_area = Task::new("Has area");
        let area = Area::new("Work");
        db.create_area(&area).unwrap();
        with_area.area_id = Some(area.id.clone());

        let mut with_date = Task::new("Has date");
        with_date.scheduled_date = Some(ScheduledDate::Someday);

        db.create_task(&inbox).unwrap();
        db.create_task(&with_area).unwrap();
        db.create_task(&with_date).unwrap();

        let result = db.get_inbox_tasks().unwrap();
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].title, "Unclassified");
    }

    #[test]
    pub fn test_task_leaves_inbox_when_date_is_assigned() {
        let db = setup();
        let mut t = Task::new("Inbox task");
        db.create_task(&t).unwrap();
        assert_eq!(db.get_inbox_tasks().unwrap().len(), 1);

        // Assigning a date moves it out of Inbox into Someday
        t.scheduled_date = Some(ScheduledDate::Someday);
        db.update_task(&t).unwrap();
        assert_eq!(db.get_inbox_tasks().unwrap().len(), 0);
        assert_eq!(db.get_someday_tasks().unwrap().len(), 1);
    }

    #[test]
    pub fn test_task_leaves_inbox_when_project_is_assigned() {
        let db = setup();
        let mut t = Task::new("Inbox task");
        db.create_task(&t).unwrap();
        assert_eq!(db.get_inbox_tasks().unwrap().len(), 1);

        let p = Project::new("My project");
        db.create_project(&p).unwrap();
        t.project_id = Some(p.id.clone());
        db.update_task(&t).unwrap();

        // Now has a project but no date → Anytime (not Inbox)
        assert_eq!(db.get_inbox_tasks().unwrap().len(), 0);
        assert_eq!(db.get_anytime_tasks().unwrap().len(), 1);
    }

    #[test]
    pub fn test_today_view() {
        let db = setup();
        let today = Local::now().date_naive();
        let future = NaiveDate::from_ymd_opt(2099, 12, 31).unwrap();

        let mut today_task = Task::new("Today task");
        today_task.scheduled_date = Some(ScheduledDate::On {
            date: today,
            time: None,
        });

        let mut future_task = Task::new("Future task");
        future_task.scheduled_date = Some(ScheduledDate::On {
            date: future,
            time: None,
        });

        let mut someday_task = Task::new("Someday task");
        someday_task.scheduled_date = Some(ScheduledDate::Someday);

        db.create_task(&today_task).unwrap();
        db.create_task(&future_task).unwrap();
        db.create_task(&someday_task).unwrap();

        let today_results = db.get_today_tasks().unwrap();
        assert_eq!(today_results.len(), 1, "Only today's task should appear");
        assert_eq!(today_results[0].title, "Today task");
    }

    #[test]
    pub fn test_today_view_with_notification_time() {
        // A task scheduled today with a time should still appear in Today.
        let db = setup();
        let today = Local::now().date_naive();
        let mut t = Task::new("Morning standup");
        t.scheduled_date = Some(ScheduledDate::On {
            date: today,
            time: Some(NaiveTime::from_hms_opt(9, 30, 0).unwrap()),
        });
        db.create_task(&t).unwrap();
        assert_eq!(db.get_today_tasks().unwrap().len(), 1);
    }

    #[test]
    pub fn test_upcoming_view() {
        let db = setup();
        let future = NaiveDate::from_ymd_opt(2099, 12, 31).unwrap();
        let today = Local::now().date_naive();

        let mut upcoming = Task::new("Future task");
        upcoming.scheduled_date = Some(ScheduledDate::On {
            date: future,
            time: None,
        });
        let mut today_task = Task::new("Today task");
        today_task.scheduled_date = Some(ScheduledDate::On {
            date: today,
            time: None,
        });
        let mut someday = Task::new("Someday");
        someday.scheduled_date = Some(ScheduledDate::Someday);

        db.create_task(&upcoming).unwrap();
        db.create_task(&today_task).unwrap();
        db.create_task(&someday).unwrap();

        let results = db.get_upcoming_tasks().unwrap();
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].title, "Future task");
    }

    #[test]
    pub fn test_anytime_view_includes_today_and_past_excludes_inbox_and_someday() {
        let db = setup();

        let inbox = Task::new("Inbox task"); // no date, no proj/area → Inbox (NOT Anytime)

        let area = Area::new("Work");
        db.create_area(&area).unwrap();
        let mut with_area = Task::new("Area task, no date"); // has area, no date → Anytime
        with_area.area_id = Some(area.id.clone());

        let mut someday = Task::new("Someday task");
        someday.scheduled_date = Some(ScheduledDate::Someday); // Someday → Someday (NOT Anytime)

        let mut today = Task::new("Today task");
        today.scheduled_date = Some(ScheduledDate::On {
            date: Local::now().date_naive(),
            time: None,
        }); // Today → Today AND Anytime

        let mut past = Task::new("Overdue task");
        past.scheduled_date = Some(ScheduledDate::On {
            date: NaiveDate::from_ymd_opt(2000, 1, 1).unwrap(),
            time: None,
        }); // Past → Anytime (since it's not done)

        db.create_task(&inbox).unwrap();
        db.create_task(&with_area).unwrap();
        db.create_task(&someday).unwrap();
        db.create_task(&today).unwrap();
        db.create_task(&past).unwrap();

        let anytime = db.get_anytime_tasks().unwrap();
        // Should include: with_area, today, past
        assert_eq!(
            anytime.len(),
            3,
            "Anytime should have area tasks, today tasks, and overdue tasks"
        );

        let titles: Vec<String> = anytime.into_iter().map(|t| t.title).collect();
        assert!(titles.contains(&"Area task, no date".to_string()));
        assert!(titles.contains(&"Today task".to_string()));
        assert!(titles.contains(&"Overdue task".to_string()));

        let someday_results = db.get_someday_tasks().unwrap();
        assert_eq!(someday_results.len(), 1);

        let inbox_results = db.get_inbox_tasks().unwrap();
        assert_eq!(inbox_results.len(), 1);
    }

    #[test]
    pub fn test_logbook_shows_done_and_cancelled_inbox_tasks() {
        // A task completed while in the Inbox must appear in the Logbook
        // with its original context preserved (no project, no area).
        let db = setup();
        let t = Task::new("Quick inbox task"); // no project, no area
        db.create_task(&t).unwrap();
        db.complete_task(&t.id).unwrap();

        let logbook = db.get_logbook_tasks().unwrap();
        assert_eq!(logbook.len(), 1);
        assert!(logbook[0].project_id.is_none());
        assert!(logbook[0].area_id.is_none());
        assert_eq!(logbook[0].status, TaskStatus::Done);
    }
    #[test]
    pub fn test_update_on_nonexistent_id_returns_zero() {
        let db = setup();
        let ghost = Area {
            id: "ghost".to_string(),
            title: "Ghost".to_string(),
            notes: String::new(),
            is_archived: false,
            position: 0.0,
        };
        assert_eq!(db.update_area(&ghost).unwrap(), 0);
    }

    #[test]
    pub fn test_foreign_key_violation_is_rejected() {
        let db = setup();
        let mut t = Task::new("Orphan");
        t.project_id = Some("non-existent-project".to_string());
        assert!(db.create_task(&t).is_err(), "FK violation must be rejected");
    }

    #[test]
    pub fn test_task_linked_to_both_project_and_area() {
        let db = setup();
        let area = Area::new("Work");
        db.create_area(&area).unwrap();
        let mut project = Project::new("Website");
        project.area_id = Some(area.id.clone());
        db.create_project(&project).unwrap();

        let mut t = Task::new("Write copy");
        t.project_id = Some(project.id.clone());
        t.area_id = Some(area.id.clone());
        db.create_task(&t).unwrap();

        let got = db.get_task(&t.id).unwrap().unwrap();
        assert_eq!(got.project_id, Some(project.id));
        assert_eq!(got.area_id, Some(area.id));
    }

    #[test]
    pub fn test_get_all_tasks_returns_all() {
        let db = setup();
        db.create_task(&Task::new("A")).unwrap();
        db.create_task(&Task::new("B")).unwrap();
        db.create_task(&Task::new("C")).unwrap();
        assert_eq!(db.get_all_tasks().unwrap().len(), 3);
    }

}
