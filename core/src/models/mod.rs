use crate::UniffiCustomTypeConverter;
use chrono::{NaiveDate, NaiveTime};
use serde::{Deserialize, Serialize};

pub mod area;
pub mod project;
pub mod task;

pub use area::*;
pub use project::*;
pub use task::*;

// Tell uniFFI how to handle NaiveDate and NaiveTime by passing them as Strings over the FFI boundary.
uniffi::custom_type!(NaiveDate, String);
impl UniffiCustomTypeConverter for NaiveDate {
    type Builtin = String;
    fn into_custom(val: Self::Builtin) -> uniffi::Result<Self> {
        val.parse().map_err(|e: chrono::ParseError| e.into())
    }
    fn from_custom(obj: Self) -> Self::Builtin {
        obj.to_string()
    }
}

uniffi::custom_type!(NaiveTime, String);
impl UniffiCustomTypeConverter for NaiveTime {
    type Builtin = String;
    fn into_custom(val: Self::Builtin) -> uniffi::Result<Self> {
        val.parse().map_err(|e: chrono::ParseError| e.into())
    }
    fn from_custom(obj: Self) -> Self::Builtin {
        obj.to_string()
    }
}

// ============================================================================
// ScheduledDate
// ============================================================================

/// When an item is scheduled to be worked on.
///
/// `None` (absence of this field) means "no date" → Anytime or Inbox.
/// `Someday` means "deferred, no concrete date" → Someday view.
/// `On { date, time }` means "scheduled for this day, optionally at this time".
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, uniffi::Enum)]
pub enum ScheduledDate {
    /// Deferred indefinitely. Item appears in the Someday view.
    Someday,
    /// Scheduled for a specific day, with an optional notification time.
    On {
        date: NaiveDate,
        /// If set, a local notification will fire at this time on `date`.
        time: Option<NaiveTime>,
    },
}

impl ScheduledDate {
    /// Serialises to the SQLite TEXT format.
    pub fn to_db_string(&self) -> String {
        match self {
            ScheduledDate::Someday => "someday".to_string(),
            ScheduledDate::On { date, time: None } => date.to_string(),
            ScheduledDate::On {
                date,
                time: Some(t),
            } => {
                format!("{} {}", date, t.format("%H:%M"))
            }
        }
    }

    /// Deserialises from the SQLite TEXT format.
    pub fn from_db_string(s: &str) -> Result<Self, String> {
        if s == "someday" {
            return Ok(ScheduledDate::Someday);
        }
        // "YYYY-MM-DD HH:MM" — split on the space
        if let Some((date_str, time_str)) = s.split_once(' ') {
            let date = date_str
                .parse::<NaiveDate>()
                .map_err(|e| format!("Invalid date '{}': {}", date_str, e))?;
            let time = NaiveTime::parse_from_str(time_str, "%H:%M")
                .map_err(|e| format!("Invalid time '{}': {}", time_str, e))?;
            return Ok(ScheduledDate::On {
                date,
                time: Some(time),
            });
        }
        // "YYYY-MM-DD" — date only
        let date = s
            .parse::<NaiveDate>()
            .map_err(|e| format!("Invalid scheduled date '{}': {}", s, e))?;
        Ok(ScheduledDate::On { date, time: None })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_scheduled_date_someday_round_trip() {
        let sd = ScheduledDate::Someday;
        let db_str = sd.to_db_string();
        assert_eq!(db_str, "someday");
        assert_eq!(ScheduledDate::from_db_string(&db_str).unwrap(), sd);
    }

    #[test]
    fn test_scheduled_date_date_only_round_trip() {
        let date = NaiveDate::from_ymd_opt(2026, 9, 30).unwrap();
        let sd = ScheduledDate::On { date, time: None };
        let db_str = sd.to_db_string();
        assert_eq!(db_str, "2026-09-30");
        assert_eq!(ScheduledDate::from_db_string(&db_str).unwrap(), sd);
    }

    #[test]
    fn test_scheduled_date_with_time_round_trip() {
        let date = NaiveDate::from_ymd_opt(2026, 9, 30).unwrap();
        let time = NaiveTime::from_hms_opt(14, 30, 0).unwrap();
        let sd = ScheduledDate::On {
            date,
            time: Some(time),
        };
        let db_str = sd.to_db_string();
        assert_eq!(db_str, "2026-09-30 14:30");
        assert_eq!(ScheduledDate::from_db_string(&db_str).unwrap(), sd);
    }

    #[test]
    fn test_scheduled_date_rejects_garbage() {
        assert!(ScheduledDate::from_db_string("not-a-date").is_err());
        assert!(ScheduledDate::from_db_string("2026-99-99").is_err());
        assert!(ScheduledDate::from_db_string("2026-06-20 99:99").is_err());
        assert!(ScheduledDate::from_db_string("").is_err());
    }
}
