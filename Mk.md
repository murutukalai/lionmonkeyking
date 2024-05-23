```rust
// Api - Task

use serde::Serialize;
use std::collections::HashMap;
use tokio_postgres::types::ToSql;

use crate::{ApiError, ApiListResponse, DBConnection};

#[derive(Debug, Clone)]
pub struct TaskGetListOptions {
    pub keyword: Option<String>,
    pub project_id: Option<String>,
    pub assignee_id: Option<i64>,
}

#[derive(Debug, Serialize, Clone)]
pub struct TaskItem {
    pub status: String,
    pub tasks: Vec<Task>,
}

#[derive(Debug, Serialize, Clone)]
pub struct Task {
    pub priority: i16,
    pub display_priority: String,
    pub task: Vec<TaskDetail>,
}

#[derive(Debug, Serialize, Clone)]
pub struct TaskDetail {
    pub priority: i16,
    pub code: String,
    pub title: String,
    pub status: String,
    pub assignee_name: String,
}

/* Private Functions */

fn get_display_task_status(status: String) -> String {
    match status.as_str() {
        "O" => "Open",
        "I" => "In progress",
        "P" => "Paused",
        "R" => "Resolved",
        "C" => "Closed",
        "V" => "Rejected",
        "W" => "Reviewed",
        _ => "Unknown",
    }
    .to_string()
}

fn get_display_task_priority(priority: i16) -> String {
    match priority {
        1 => "Low",
        2 => "Normal",
        3 => "High",
        4 => "Urgent",
        _ => "Unknown",
    }
    .to_string()
}

/* Public Functions */

pub async fn get_list(
    db: &DBConnection<'_>,
    user_id: i64,
    employee_id: i64,
    options: &TaskGetListOptions,
) -> Result<Vec<TaskItem>, ApiError> {
    let task_map: HashMap<String, Vec<Task>> = HashMap::new();
    let mut query = " FROM task t INNER JOIN employee e ON t.assignee_id = e.id".to_string();

    let mut params: Vec<&(dyn ToSql + Sync)> = Vec::new();
    let mut where_clauses: Vec<String> = vec![];
    let mut task_ids: Vec<i64> = vec![];

    let project_ids: Vec<i64> = vec![];
    if let Some(row) = db
        .query_opt(
            "SELECT ARRAY_AGG(project_id) AS project_ids
                FROM project_member WHERE employee_id = $1",
            &[&user_id],
        )
        .await?
    {
        task_ids = row.get("project_ids")
    } else {
        return Ok(vec![]);
    };
    where_clauses.push(format!("project_id = ANY(${})", params.len() + 1));
    params.push(&task_ids);

    if let Some(assignee_id) = &options.assignee_id {
        if let Some(row) = db
            .query_opt(
                "SELECT ARRAY_AGG(task_id) AS task_ids
                FROM task_assignee WHERE assignee_id = $1",
                &[&assignee_id],
            )
            .await?
        {
            task_ids = row.get("task_ids")
        } else {
            return Ok(vec![]);
        };
        where_clauses.push(format!("id = ANY(${})", params.len() + 1));
        params.push(&task_ids);
    }

    let int_key: String;
    if let Some(key) = &options.keyword.clone() {
        where_clauses.push(format!(
            "(t.tags LIKE ${} OR t.title ~* ${})",
            params.len() + 1,
            params.len() + 2
        ));
        int_key = format!("%#{}#%", key);
        params.push(&int_key);
        params.push(&options.keyword);
    }

    if let Some(project_id) = &options.project_id {
        where_clauses.push(format!("t.project_id = ${}", params.len() + 1));
        params.push(&project_id)
    }

    if !where_clauses.is_empty() {
        query += " WHERE ";
        query += where_clauses.join(" AND ").as_str();
    }

    query = format!(
        "SELECT t.code, t.priority, t.code, t.title, t.status, e.name {}",
        query
    );

    let rows = db.query(&query, &params).await?;
    

    Ok(())
}
```
```sql
INSERT INTO task (project_id, module_id, version_id, priority, created_by, code, title, content, content_html, tags, due_on, completed_on, status, assignee_id)
VALUES
(1, 1, 1, 1, 'admin', 'TASK001', 'Design Homepage', 'Create wireframes and mockups for the homepage design.', '<p>Create wireframes and mockups for the homepage design.</p>', 'design, homepage, wireframe, mockup', '2024-06-15', NULL, 'O', 1),
(1, 1, 1, 1, 'admin', 'TASK002', 'Implement Navigation', 'Implement navigation bar and menu functionality.', '<p>Implement navigation bar and menu functionality.</p>', 'navigation, menu, frontend', '2024-06-20', NULL, 'O', 1),
(4, 1, 1, 1, 'admin', 'TASK003', 'Backend Database Setup', 'Set up the backend database structure for the project.', '<p>Set up the backend database structure for the project.</p>', 'backend, database, setup', '2024-06-10', NULL, 'O', 1),
(4, 1, 1, 1, 'admin', 'TASK004', 'API Integration', 'Integrate external APIs for fetching data.', '<p>Integrate external APIs for fetching data.</p>', 'API, integration, backend', '2024-06-25', NULL, 'O', 1),
(4, 1, 1, 1, 'admin', 'TASK005', 'Testing', 'Perform unit and integration testing for the application.', '<p>Perform unit and integration testing for the application.</p>', 'testing, QA, unit testing, integration testing', '2024-06-30', NULL, 'O', 1);

INSERT INTO task_assignee(project_id, task_id, assignee_id, role, is_notify) VALUES
(1, 2, 1, 'dev', 't'),
(1, 1, 1, 'dev', 't'),
(1, 2, 2, 'dev', 't'),
(1, 1, 2, 'dev', 't'),
(1, 2, 3, 'dev', 't'),
(1, 1, 3, 'dev', 't'),
(1, 2, 4, 'dev', 't'),
(1, 2, 4, 'dev', 't'),
(4, 3, 4, 'dev', 't'),
(4, 4, 4, 'dev', 't'),
(4, 5, 4, 'dev', 't');
```
