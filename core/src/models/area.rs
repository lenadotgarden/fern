use serde::{Deserialize, Serialize};
use uuid::Uuid;

// ============================================================================
// Area
// ============================================================================

/// Top-level organisational container (e.g. "Work", "Personal").
///
/// Areas have no status — they can only be active (visible) or archived
/// (hidden from the sidebar, but all data is preserved).
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, uniffi::Record)]
pub struct Area {
    pub id: String,
    pub title: String,
    pub notes: String,
    /// Archived areas are hidden but never deleted. All their projects and tasks
    /// remain queryable and are preserved for history and future sync.
    pub is_archived: bool,
    /// Manual sort order. Fractional indexing is used for efficient reordering.
    pub position: f64,
}

impl Area {
    pub fn new(title: impl Into<String>) -> Self {
        Area {
            id: Uuid::now_v7().to_string(),
            title: title.into(),
            notes: String::new(),
            is_archived: false,
            position: 0.0,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_area_new_defaults() {
        let a = Area::new("Work");
        assert_eq!(a.title, "Work");
        assert!(a.notes.is_empty());
        assert!(!a.is_archived, "new area should not be archived");
        assert!(uuid::Uuid::parse_str(&a.id).is_ok());
    }

    #[test]
    fn test_two_areas_have_distinct_ids() {
        assert_ne!(Area::new("Work").id, Area::new("Personal").id);
    }
}
