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

pub async fn get_team_options(
    db: &DBConnection<'_>,
) -> Result<HashMap<i64, TeamEmployeeOption>, ApiError> {
    let mut teams: HashMap<i64, TeamEmployeeOption> = HashMap::new();

    let team_rows = db
        .query("SELECT id, name, type FROM team ORDERED BY created_on", &[])
        .await?;

    for row in team_rows {
        let team_id = row.get("id");
        let team_option = TeamEmployeeOption {
            id: team_id,
            name: row.get("name"),
            team_type: row.get("type"),
            employees: vec![],
        };
        teams.insert(team_id, team_option);
    }

    let rows = db
        .query(
            "SELECT id, name, team_id FROM team_employee AS te 
                INNER JOIN employee AS e ON te.employee_id = e.id",
            &[],
        )
        .await?;

    for row in rows {
        let team_id = row.get("team_id");
        let employee_option = EmployeeOption {
            id: row.get("id"),
            name: row.get("name"),
        };
        if let Some(team) = teams.get_mut(&team_id) {
            team.employees.push(employee_option);
        }
    }

    Ok(teams)
}

```
