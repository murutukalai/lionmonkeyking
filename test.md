```rust

// Api - Common Module - QuickMenu

use anyhow::Result;
use serde::Serialize;
use tracing::info;
use std::collections::HashMap;

use crate::{ApiError, DBConnection};

#[derive(Debug, Clone, Serialize)]
pub struct QuickLink {
    pub menu_type: String,
    pub path: String,
    pub title: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct QuickLinkGroup {
    pub group: String,
    pub links: Vec<QuickLink>,
}

pub async fn get_links_by_employee(
    db: &DBConnection<'_>,
    employee_id: i64,
    keyword: &String,
) -> Result<Vec<QuickLinkGroup>, ApiError> {
    let mut quick_map: HashMap<String, Vec<QuickLink>> = HashMap::new();
    let rows = db
        .query(
            "SELECT rp.privilege_id, qm.title, qm.url_path, qm.category FROM employee_role er 
            INNER JOIN role_privilege rp ON er.role_id = rp.role_id
            INNER JOIN quick_menu qm ON rp.privilege_id = qm.privilege_id 
            WHERE employee_id = $1 AND title ~* $2",
            &[&employee_id, &keyword],
        )
        .await?;

    info!("{}", rows.len());

    for row in rows {
        if let Some(team) = quick_map.get_mut(&row.get::<_, String>("category")) {
            team.push(QuickLink {
                menu_type: "link".to_string(),
                path: row.get("url_path"),
                title: row.get("title"),
            });
            info!("row1{}", row.len());
        } else {
            quick_map.insert(
                row.get("category"),
                vec![QuickLink {
                    menu_type: "link".to_string(),
                    path: row.get("url_path"),
                    title: row.get("title"),
                }],
            );
            info!("row1{}", row.len());
        }
    }

    let rows = db
        .query(
            "SELECT ep.privilege_id, qm.title, qm.url_path, qm.category FROM quick_menu qm
            INNER JOIN employee_privilege ep ON qm.privilege_id = ep.privilege_id
            WHERE ep.employee_id = $1 AND title ~* $2",
            &[&employee_id, &keyword],
        )
        .await?;

    for row in rows {
        if let Some(team) = quick_map.get_mut(&row.get::<_, String>("category")) {
            team.push(QuickLink {
                menu_type: "link".to_string(),
                path: row.get("url_path"),
                title: row.get("title"),
            });
        } else {
            quick_map.insert(
                row.get("category"),
                vec![QuickLink {
                    menu_type: "link".to_string(),
                    path: row.get("url_path"),
                    title: row.get("title"),
                }],
            );
        }
    }

    let mut items: Vec<QuickLinkGroup> = vec![];
    for (k, v) in quick_map {
        items.push(QuickLinkGroup { group: k, links: v })
    }

    Ok(items)
}


```
