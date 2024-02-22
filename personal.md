```rust
// Api - Task

use chrono::{self, NaiveDate};
use serde::{Deserialize, Serialize};
use tokio_postgres::types::ToSql;

use super::ApiError;
use crate::db::DBConnection;

/* Constants */
const STATUS_OPEN: &str = "O";

/* Structs */

#[derive(Debug, Deserialize, Serialize)]
pub struct Task {
    pub id: i64,
    pub project_id: i64,
    pub requirement_id: Option<i64>,
    pub assignee_id: i64,
    pub title: String,
    pub description: Option<String>,
    pub status: String,
    pub priority: i16,
    pub due_date: chrono::NaiveDate,
}

#[derive(Debug, Deserialize)]
pub struct TaskUpdateInput {
    pub title: Option<String>,
    pub description: Option<String>,
    pub assignee_id: Option<i64>,
    pub priority: Option<i16>,
    pub due_date: Option<chrono::NaiveDate>,
}

#[derive(Debug, Serialize, Clone)]
pub struct TaskItem {
    pub id: i64,
    pub title: String,
    pub status: String,
    pub priority: String,
    pub task_type: String,
    pub due_date: String,
    pub created_by: String,
    pub assignee_name: String,
    pub project_title: String,
    pub project_slug: String,
    pub technical_type: Option<String>,
    pub requirement_id: Option<i64>,
    pub description: Option<String>,
}

#[derive(Debug, Serialize, Clone)]
pub struct TaskGroup {
    pub priority: String,
    pub tasks: Vec<TaskItem>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct TaskCreateInput {
    pub title: String,
    pub priority: i16,
    pub assignee_id: i64,
    pub due_date: NaiveDate,
    pub description: Option<String>,
}

pub struct TaskCreateOptions {
    pub created_by: String,
    pub created_by_id: i64,
    pub technical_type: Option<String>,
    pub task_type: String,
}

/* Private Function */

/* Public Function */

pub async fn get_employee_due_list(
    db: &DBConnection<'_>,
    emp_id: i64,
) -> Result<Vec<TaskGroup>, ApiError> {
    let current_date: chrono::NaiveDate = chrono::Local::now().naive_local().into();
    let rows = db
        .query(
            r#"SELECT t.id, t.requirement_id, t.title, t.description, t.status, t.priority,
            t.due_date, t.technical_type, t.created_by, t.type, e.username, p.name, p.slug
            FROM task t
            INNER JOIN employee e ON e.id = t.employee_id
            INNER JOIN project p ON p.id = t.project_id
            WHERE employee_id = $1 AND due_date <= $2
            AND status != 'C' AND status != 'V'
            ORDER BY priority DESC, due_date;"#,
            &[&emp_id, &current_date],
        )
        .await?;

    let mut task_groups: Vec<TaskGroup> = Vec::new();
    for row in rows {
        let status = match row.get::<_, String>("status").as_str() {
            "O" => "Open".to_string(),
            "I" => "In progress".to_string(),
            "R" => "Resolved".to_string(),
            "C" => "Closed".to_string(),
            "V" => "Rejected".to_string(),
            _ => "Unknown".to_string(),
        };

        let priority = match row.get::<_, i16>("priority") {
            1 => "Low".to_string(),
            2 => "Normal".to_string(),
            3 => "High".to_string(),
            4 => "Urgent".to_string(),
            _ => "Unknown".to_string(),
        };

        let task: TaskItem = TaskItem {
            id: row.get("id"),
            title: row.get("title"),
            status,
            priority,
            task_type: row.get("type"),
            due_date: (row.get::<_, NaiveDate>("due_date")).to_string(),
            created_by: row.get("created_by"),
            assignee_name: row.get("username"),
            project_title: row.get("name"),
            project_slug: row.get("slug"),
            requirement_id: row.get("requirement_id"),
            technical_type: row.get("technical_type"),
            description: row.get("description"),
        };

        if let Some(index) = task_groups
            .iter()
            .position(|el| el.priority == task.priority)
        {
            task_groups[index].tasks.push(task);
        } else {
            task_groups.push(TaskGroup {
                priority: task.priority.clone(),
                tasks: vec![task],
            });
        }
    }

    Ok(task_groups)
}

pub async fn get_by_id(db: &DBConnection<'_>, task_id: i64) -> Result<Task, ApiError> {
    let rows = db
        .query("SELECT * FROM task WHERE id = $1 ", &[&task_id])
        .await?;

    let Some(row) = rows.first() else {
        return Err(ApiError::Error(format!(
            "Design system item with id '{}' does not exist",
            task_id
        )));
    };

    Ok(Task {
        id: row.get("id"),
        project_id: row.get("project_id"),
        requirement_id: row.get("requirement_id"),
        assignee_id: row.get("employee_id"),
        title: row.get("title"),
        description: row.get("description"),
        status: row.get("status"),
        priority: row.get("priority"),
        due_date: row.get("due_date"),
    })
}

pub async fn create(
    db: &DBConnection<'_>,
    project_id: i64,
    req_id: Option<i64>,
    options: &TaskCreateOptions,
    input: &TaskCreateInput,
) -> Result<i64, ApiError> {
    let query = r#"
        INSERT INTO task(project_id, requirement_id, employee_id, type,
            technical_type, title, description, status, priority, due_date,
            created_by_id, created_by, is_closed, is_rejected) VALUES
            ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
            RETURNING id
    "#;
    let rows = db
        .query(
            &query.to_string(),
            &[
                &project_id,
                &req_id,
                &input.assignee_id,
                &options.task_type,
                &options.technical_type,
                &input.title,
                &input.description,
                &STATUS_OPEN,
                &input.priority,
                &input.due_date,
                &options.created_by_id,
                &options.created_by,
                &false,
                &false,
            ],
        )
        .await?;
    let Some(row) = rows.first() else {
        return Err(ApiError::Error("Unable to create new usecase".to_string()));
    };

    Ok(row.get(0))
}

pub async fn update_by_id(
    db: &DBConnection<'_>,
    task_id: i64,
    input: TaskUpdateInput,
) -> Result<bool, ApiError> {
    let mut set_clauses: Vec<String> = Vec::new();
    let mut params: Vec<&(dyn ToSql + Sync)> = Vec::new();

    if let Some(title) = &input.title {
        set_clauses.push(format!("title = ${}", params.len() + 1));
        params.push(title)
    }

    if let Some(priority) = &input.priority {
        set_clauses.push(format!("priority = ${}", params.len() + 1));
        params.push(priority)
    }

    if let Some(due_date) = &input.due_date {
        set_clauses.push(format!("due_date = ${}", params.len() + 1));
        params.push(due_date)
    }

    let query = format!(
        "UPDATE task SET {} WHERE id = ${} ",
        set_clauses.join(", "),
        params.len() + 1,
    );

    if set_clauses.is_empty() {
        return Err(ApiError::Error(
            "Enter minimum one data to update".to_string(),
        ));
    }
    params.push(&task_id);
    let val = db.execute(&query, &params).await?;
    Ok(val != 0)
}

```


```rust
// Route - Web - Task

use axum::{response::Html, Extension};
use sailfish::TemplateOnce;

use super::{WebAuthUser, WebResult};
use crate::{
    api::{
        employee::{self, EmployeeInfo},
        task::{self, TaskGroup},
    },
    state::ExtAppState,
};

#[derive(TemplateOnce)]
#[template(path = "pages/task_employee.stpl")]
struct TemplateTaskContent {
    page_title: String,
    user_name: String,
    items: Vec<TaskGroup>,
    task_assignees: Vec<EmployeeInfo>,
}

pub async fn handle_employee_tasks(
    user: WebAuthUser,
    Extension(app_state): ExtAppState,
) -> WebResult {
    let db = app_state.db.conn().await?;
    let items = task::get_employee_due_list(&db, user.id).await?;
    let task_assignees = employee::get_list(&db).await?;

    let ctx = TemplateTaskContent {
        page_title: "Task".to_string(),
        user_name: user.name.clone(),
        items,
        task_assignees,
    };
    Ok(Html(ctx.render_once().unwrap()))
}

```
