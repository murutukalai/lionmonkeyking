```rust
// Api - Employee

use serde::Serialize;
use std::collections::HashMap;

use super::ApiError;
use crate::db::DBConnection;

/* Struct */

#[derive(Debug, Serialize)]

pub struct EmployeeOption {
    id: i64,
    name: String,
}

#[derive(Debug, Serialize)]
pub struct TeamEmployeeOption {
    id: i64,
    name: String,
    team_type: String,
    employees: Vec<EmployeeOption>,
}

/* Public Functions*/

pub async fn get_team_options(db: &DBConnection<'_>) -> Result<HashMap<i64, TeamEmployeeOption>, ApiError> {
    let mut teams: HashMap<i64, TeamEmployeeOption> = HashMap::new();

    let team_rows = db
        .query("SELECT id, name, type FROM team ORDER BY created_on", &[])
        .await?;

    for row in &team_rows {
        teams.insert(
            row.get("id"),
            TeamEmployeeOption {
                id: row.get("id"),
                name: row.get("name"),
                team_type: row.get("type"),
                employees: vec![],
            },
        );
    }

    let rows = db
        .query(
            "SELECT te.id AS team_id, e.id, e.name FROM team_employee AS te 
                INNER JOIN employee AS e ON te.employee_id = e.id",
            &[],
        )
        .await?;

    for row in &rows {
        if let Some(team_option) = teams.get_mut(&row.get("team_id")) {
            team_option.employees.push(EmployeeOption {
                id: row.get("id"),
                name: row.get("name"),
            });
        }
    }

    Ok(teams)
}
```
