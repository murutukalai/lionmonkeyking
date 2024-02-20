```rust
// Api - Task

use chrono::{self, NaiveDate};
use serde::{Deserialize, Serialize};
use tokio_postgres::types::ToSql;
use tracing::info;

use super::ApiError;
use crate::db::DBConnection;

/* Constants */
const STATUS_OPEN: &str = "O";

/* Structs */

#[derive(Debug, Deserialize, Serialize)]
pub struct Task {
    pub id: i64,
    pub project_id: i64,
    pub created_by_id: i64,
    pub requirement_id: i64,
    pub employee_id: i64,
    pub title: String,
    pub description: String,
    pub status: String,
    pub priority: i8,
    pub due_date: chrono::NaiveDate,
    pub created_by: String,
    pub tast_type: String,
    pub is_closed: bool,
    pub is_rejected: bool,
}

#[derive(Debug, Deserialize)]
pub struct TaskUpdateInput {
    pub title: Option<String>,
    pub priority: Option<String>,
    pub due_date: Option<chrono::NaiveDate>,
}

#[derive(Debug, Serialize, Clone)]
pub struct TaskList {
    pub id: i64,
    pub title: String,
    pub description: Option<String>,
    pub status: String,
    pub priority: String,
    pub task_type: String,
    pub due_date: NaiveDate,
    pub created_by: String,
    pub assignee_name: String,
    pub project_title: String,
}

#[derive(Debug, Serialize, Clone)]
pub struct TaskGroup {
    pub priority: String,
    pub task: Vec<TaskList>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct TaskCreateInput {
    pub title: String,
    pub priority: String,
    pub assignee_id: i64,
    pub due_date: NaiveDate,
    pub description: Option<String>,
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
            r#"SELECT t.id, t.title, t.description, t.status, t.priority, t.due_date,
            t.created_by, t.type, e.username, p.name
            FROM task t
            INNER JOIN employee e ON e.id = t.employee_id
            INNER JOIN project p ON p.id = t.project_id
            WHERE employee_id = $1 AND due_date <= $2
            AND status != 'C' AND status != 'R'
            ORDER BY priority, due_date;"#,
            &[&emp_id, &current_date],
        )
        .await?;

        let mut task_group_vec: Vec<TaskGroup> = Vec::new();
    let mut vec_priority: Vec<String> = Vec::new();

    for row in rows {
        let task: TaskList = TaskList {
            id: row.get("id"),
            title: row.get("title"),
            description: row.get("description"),
            status: row.get("status"),
            priority: row.get("priority"),
            task_type: row.get("type"),
            due_date: row.get("due_date"),
            created_by: row.get("created_by"),
            assignee_name: row.get("username"),
            project_title: row.get("name"),
        };

        if !vec_priority.contains(&task.priority) {
            vec_priority.push(task.priority.clone());
            task_group_vec.push(TaskGroup {
                priority: task.priority.clone(),
                task: vec![task],
            });
        } else {
            let index = vec_priority.iter().position(|p| p == &task.priority).unwrap();
            task_group_vec[index].task.push(task);
        }
    }

    Ok(task_group_vec)
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
        created_by_id: row.get("created_by_id"),
        requirement_id: row.get("requirement_id"),
        employee_id: row.get("employee_id"),
        title: row.get("title"),
        description: row.get("description"),
        status: row.get("status"),
        priority: row.get("priority"),
        due_date: row.get("due_date"),
        created_by: row.get("created_by"),
        tast_type: row.get("type"),
        is_closed: row.get("is_closed"),
        is_rejected: row.get("is_rejected"),
    })
}

pub async fn create(
    db: &DBConnection<'_>,
    project_id: i64,
    req_id: Option<i64>,
    created_by: String,
    created_by_id: i64,
    technical_type: &Option<String>,
    task_type: String,
    input: &TaskCreateInput,
) -> Result<i64, ApiError> {
    let mut params: Vec<&(dyn ToSql + Sync)> = Vec::new();

    let mut fields = "project_id, ".to_string();
    let mut values = format!("${}", params.len() + 1);
    params.push(&project_id);

    if req_id.is_some() {
        fields.push_str("requirement_id, ");
        values.push_str(format!(", ${}", params.len() + 1).as_str());
        params.push(&req_id)
    }

    fields.push_str("employee_id, title, priority, due_date, ");
    values.push_str(
        format!(
            ", ${}, ${}, ${}, ${}",
            params.len() + 1,
            params.len() + 2,
            params.len() + 3,
            params.len() + 4,
        )
        .as_str(),
    );
    params.push(&input.assignee_id);
    params.push(&input.title);
    params.push(&input.priority);
    params.push(&input.due_date);

    if input.description.is_some() {
        fields.push_str("description, ");
        values.push_str(format!(", ${}", params.len() + 1).as_str());
        params.push(&input.description);
    }

    if technical_type.is_some() {
        fields.push_str("technical_type, ");
        values.push_str(format!(", ${}", params.len() + 1).as_str());
        params.push(&technical_type);
    }

    fields.push_str("type, status, created_by_id, created_by, is_closed, is_rejected");
    values.push_str(
        format!(
            ", ${}, ${}, ${}, ${}, ${}, ${}",
            params.len() + 1,
            params.len() + 2,
            params.len() + 3,
            params.len() + 4,
            params.len() + 5,
            params.len() + 6,
        )
        .as_str(),
    );
    params.push(&task_type);
    params.push(&STATUS_OPEN);
    params.push(&created_by_id);
    params.push(&created_by);
    params.push(&false);
    params.push(&false);

    let query = format!(
        "INSERT INTO task({}) VALUES({}) RETURNING id",
        fields, values
    );

    info!("{params:?}");
    info!("{query}");
    let rows = db.query(&query, &params).await?;

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
// Route - Rest - Task

use axum::{extract::Path, Extension, Json};
use chrono::NaiveDate;
use serde::{Deserialize, Serialize};
use tracing::error;

use super::{RestAuthUser, RestError, RestResult};
use crate::{
    api::{
        employee, project, task::{self, Task, TaskUpdateInput}
    },
    route::rest::RestCommonResponse,
    state::ExtAppState,
};

#[derive(Serialize, Debug)]
pub struct RestTaskResponse {
    success: bool,
    item: Option<Task>,
    error: Option<String>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct TaskCreateInput {
    pub title: String,
    pub priority: String,
    pub assignee_id: String,
    pub due_date: String,
    pub description: Option<String>,
}

pub async fn handler_get(
    _user: RestAuthUser,
    Extension(app_state): ExtAppState,
    Path(task_id): Path<i64>,
) -> RestResult<RestTaskResponse> {
    let db = app_state.db.conn().await?;
    let item = task::get_by_id(&db, task_id).await?;

    Ok(Json(RestTaskResponse {
        success: true,
        item: Some(item),
        error: None,
    }))
}

pub async fn handler_project_wise_create(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
    Path(slug): Path<String>,
    Json(input): Json<TaskCreateInput>,
) -> RestResult<RestCommonResponse> {
    if !user.is_admin() {
        error!("Unauthorized access");
        return Ok(Json(RestCommonResponse {
            success: false,
            error: Some("Unauthorized access".to_string()),
        }));
    }

    let Ok(due_date) = NaiveDate::parse_from_str(input.due_date.as_str(), "%Y-%m-%d") else {
        return Err(RestError::Error(
            "Unable to convert string to date".to_string(),
        ));
    };

    let Ok(assignee_id) = input.assignee_id.parse::<i64>() else {
        return Err(RestError::Error(
            "Unable to convert string to assignee id".to_string(),
        ));
    };

    let api_input = task::TaskCreateInput{
        title: input.title,
        priority: input.priority,
        assignee_id,
        due_date,
        description: input.description
    };

    let db = app_state.db.conn().await?;
    let project = project::get_by_slug(&db, &slug).await?;
    let val = task::create(
        &db,
        project.id,
        None,
        user.name.clone(),
        user.id,
        &None,
        "T".to_string(),
        &api_input,
    )
    .await?;

    Ok(Json(RestCommonResponse {
        success: val != 0,
        error: None,
    }))
}

pub async fn handler_req_wise_create(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
    Path((slug, req_id)): Path<(String, i64)>,
    Json(input): Json<TaskCreateInput>,
) -> RestResult<RestCommonResponse> {
    if !user.is_admin() {
        error!("Unauthorized access");
        return Ok(Json(RestCommonResponse {
            success: false,
            error: Some("Unauthorized access".to_string()),
        }));
    }

    let Ok(due_date) = NaiveDate::parse_from_str(input.due_date.as_str(), "%Y-%m-%d") else {
        return Err(RestError::Error(
            "Unable to convert string to date".to_string(),
        ));
    };

    let Ok(assignee_id) = input.assignee_id.parse::<i64>() else {
        return Err(RestError::Error(
            "Unable to convert string to assignee id".to_string(),
        ));
    };

    let api_input = task::TaskCreateInput{
        title: input.title,
        priority: input.priority,
        assignee_id,
        due_date,
        description: input.description
    };

    let db = app_state.db.conn().await?;
    let project = project::get_by_slug(&db, &slug).await?;
    let technical_type = employee::get_technical_type(&db, assignee_id).await?;
    let val = task::create(
        &db,
        project.id,
        Some(req_id),
        user.name.clone(),
        user.id,
        &technical_type,
        "T".to_string(),
        &api_input,
    )
    .await?;

    Ok(Json(RestCommonResponse {
        success: val != 0,
        error: None,
    }))
}

pub async fn handler_update(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
    Path(id): Path<i64>,
    Json(input): Json<TaskUpdateInput>,
) -> RestResult<RestCommonResponse> {
    if !user.is_admin() {
        error!("Unauthorized access");
        return Ok(Json(RestCommonResponse {
            success: false,
            error: Some("Unauthorized access".to_string()),
        }));
    }

    let db = app_state.db.conn().await?;
    let success = task::update_by_id(&db, id, input).await?;

    Ok(Json(RestCommonResponse {
        success,
        error: None,
    }))
}

```
```rust
// Route - Web - Requirement

use axum::{extract::Path, response::Html, Extension};
use sailfish::TemplateOnce;

use crate::{
    api::{
        employee::{self, EmployeeInfo},
        project::{self, ProjectInfo},
        requirement::{self, Requirement, RequirementAssignees, RequirementDetail},
        team,
        usecase::{self, UseCase},
    },
    state::ExtAppState,
};

use super::{OptionItem, WebAuthUser, WebResult};

#[derive(TemplateOnce)]
#[template(path = "pages/requirement.stpl")]
pub struct TemplateRequirements {
    page_title: String,
    user_name: String,
    role_is_admin: bool,
    role_is_qa: bool,
    role_is_manager: bool,
    project: ProjectInfo,
    items: Vec<Requirement>,
    web_options: Vec<OptionItem>,
    backend_options: Vec<OptionItem>,
    mobile_options: Vec<OptionItem>,
    qa_options: Vec<OptionItem>,
    assignee_vec: Vec<EmployeeInfo>
}

/* Private Functions */

/* Public Functions */

pub async fn handler_list(
    user: WebAuthUser,
    Extension(app_state): ExtAppState,
    Path(slug): Path<String>,
) -> WebResult {
    let db = app_state.db.conn().await?;
    let project = project::get_by_slug(&db, &slug).await?;
    let items = requirement::get_list(&db, project.id, user.is_admin()).await?;

    let teams = team::get_employee_list(&db).await?;
    let mut web_options: Vec<OptionItem> = vec![];
    let mut backend_options: Vec<OptionItem> = vec![];
    let mut mobile_options: Vec<OptionItem> = vec![];
    let mut qa_options: Vec<OptionItem> = vec![];

    for team in teams.iter() {
        let options = team
            .employees
            .iter()
            .map(|row| OptionItem {
                id: row.id,
                title: row.name.clone(),
            })
            .collect();
        if team.team_type == "web" {
            web_options = options;
        } else if team.team_type == "mobile" {
            mobile_options = options;
        } else if team.team_type == "backend" {
            backend_options = options;
        } else if team.team_type == "qa" {
            qa_options = options;
        }
    }

    let assignee_vec = employee::employee_list(&db).await?;
    let page_title = format!("{} - Requirements", project.title);
    let ctx = TemplateRequirements {
        page_title,
        user_name: user.name.clone(),
        role_is_admin: user.is_admin(),
        role_is_qa: user.is_qa(),
        role_is_manager: user.is_manager(),
        project,
        items,
        web_options,
        backend_options,
        mobile_options,
        qa_options,
        assignee_vec
    };
    Ok(Html(ctx.render_once().unwrap()))
}

#[derive(TemplateOnce)]
#[template(path = "pages/usecase.stpl")]
pub struct TemplateUseCaseList {
    page_title: String,
    user_name: String,
    role_is_admin: bool,
    role_is_qa: bool,
    role_is_manager: bool,
    project: ProjectInfo,
    requirement: RequirementDetail,
    is_assignee: bool,
    items: Vec<UseCase>,
    web_options: Vec<OptionItem>,
    backend_options: Vec<OptionItem>,
    mobile_options: Vec<OptionItem>,
    qa_options: Vec<OptionItem>,
    assignees: RequirementAssignees,
    assignee_vec: Vec<EmployeeInfo>,
}

pub async fn handler_detail(
    user: WebAuthUser,
    Extension(app_state): ExtAppState,
    Path((slug, req_id)): Path<(String, i64)>,
) -> WebResult {
    let db = app_state.db.conn().await?;
    let project = project::get_by_slug(&db, &slug).await?;
    let items = usecase::get_list(&db, project.id, req_id, user.is_admin()).await?;
    let requirement = requirement::get_by_id(&db, project.id, req_id).await?;
    // let docs = document::get_list(&db, project.id, req_id, user.is_admin()).await?;
    let assignees = requirement::get_assignee_names(&db, &requirement).await?;

    let mut assignee_id_vec = vec![];
    if let Some(web_assignee_id) = requirement.web_assignee_id {
        assignee_id_vec.push(web_assignee_id)
    }
    if let Some(mobile_assignee_id) = requirement.mobile_assignee_id {
        assignee_id_vec.push(mobile_assignee_id)
    }
    if let Some(backend_assignee_id) = requirement.backend_assignee_id {
        assignee_id_vec.push(backend_assignee_id)
    }
    if let Some(qa_assignee_id) = requirement.qa_assignee_id {
        assignee_id_vec.push(qa_assignee_id)
    }

    let assignee_map = employee::get_names_by_ids(&db, assignee_id_vec).await?;
    let assignee_vec = assignee_map.values().cloned().collect();
    let mut is_assignee = false;
    if requirement.web_assignee_id == Some(user.id)
        || requirement.mobile_assignee_id == Some(user.id)
        || requirement.backend_assignee_id == Some(user.id)
        || requirement.qa_assignee_id == Some(user.id)
    {
        is_assignee = true
    }
    let teams = team::get_employee_list(&db).await?;
    let mut web_options: Vec<OptionItem> = vec![];
    let mut backend_options: Vec<OptionItem> = vec![];
    let mut mobile_options: Vec<OptionItem> = vec![];
    let mut qa_options: Vec<OptionItem> = vec![];

    for team in teams.iter() {
        let options = team
            .employees
            .iter()
            .map(|row| OptionItem {
                id: row.id,
                title: row.name.clone(),
            })
            .collect();
        if team.team_type == "web" {
            web_options = options;
        } else if team.team_type == "mobile" {
            mobile_options = options;
        } else if team.team_type == "backend" {
            backend_options = options;
        } else if team.team_type == "qa" {
            qa_options = options;
        }
    }

    let page_title = format!("{} - Requirements - {}", project.title, req_id);
    let ctx = TemplateUseCaseList {
        page_title,
        user_name: user.name.clone(),
        role_is_admin: user.is_admin(),
        role_is_qa: user.is_qa(),
        role_is_manager: user.is_manager(),
        project,
        requirement,
        is_assignee,
        items,
        web_options,
        backend_options,
        mobile_options,
        qa_options,
        assignees,
        assignee_vec,
    };
    Ok(Html(ctx.render_once().unwrap()))
}

```
```rust
// Api - Employee

use serde::Serialize;
use std::collections::HashMap;

use super::ApiError;
use crate::db::DBConnection;

/* Struct */

#[derive(Debug, Clone, Serialize)]
pub struct EmployeeInfo {
    pub id: i64,
    pub name: String,
}

/* Private Functions */

/* Public Functions */

pub async fn get_by_username(
    db: &DBConnection<'_>,
    username: &String,
) -> Result<EmployeeInfo, ApiError> {
    let rows = db
        .query(
            "SELECT id, name FROM employee WHERE username = $1",
            &[&username.to_lowercase()],
        )
        .await?;

    let Some(row) = rows.first() else {
        return Err(ApiError::Error(format!(
            "Employee with username {} does not exist",
            username
        )));
    };

    Ok(EmployeeInfo {
        id: row.get("id"),
        name: row.get("name"),
    })
}

pub async fn get_names_by_ids(
    db: &DBConnection<'_>,
    employee_ids: Vec<i64>,
) -> Result<HashMap<i64, EmployeeInfo>, ApiError> {
    let rows = db
        .query(
            "SELECT id, name FROM employee WHERE id = ANY($1)",
            &[&employee_ids],
        )
        .await?;

    let mut employee_list: HashMap<i64, EmployeeInfo> = HashMap::new();
    for row in rows {
        employee_list.insert(
            row.get("id"),
            EmployeeInfo {
                id: row.get("id"),
                name: row.get("name"),
            },
        );
    }

    Ok(employee_list)
}

pub async fn get_technical_type(
    db: &DBConnection<'_>,
    emp_id: i64,
) -> Result<Option<String>, ApiError> {
    let opt_row = db
        .query_opt(
            r#"SELECT t.type
               FROM team_employee AS te 
               INNER JOIN team AS t ON te.team_id = t.id
               WHERE te.employee_id = $1"#,
            &[&emp_id],
        )
        .await?;

    let Some(row) = opt_row else {
        return Ok(None);
    };

    if *"qa" == row.get::<_, String>(0) {
        return Ok(None);
    }

    Ok(row.get(0))
}

pub async fn employee_list(db: &DBConnection<'_>) -> Result<Vec<EmployeeInfo>, ApiError> {
    let rows = db.query("SELECT id, name FROM employee", &[]).await?;

    let employee_vec: Vec<EmployeeInfo> = rows
        .iter()
        .map(|row| EmployeeInfo {
            id: row.get("id"),
            name: row.get("name"),
        })
        .collect();

    Ok(employee_vec)
}

```


