```sql
INSERT INTO requirement (project_id, requirement, description, status, progress) VALUES
    (1, 'Req 1 for Project 1', 'Description for Req 1', 'new', 25),
    (1, 'Req 2 for Project 1', 'Description for Req 2', 'In Progress', 50),
    (2, 'Req 1 for Project 2', 'Description for Req 1', 'Completed', 100),
    (2, 'Req 2 for Project 2', 'Description for Req 2', 'new', 10),
    (3, 'Req 1 for Project 3', 'Description for Req 1', 'In Progress', 75),
    (3, 'Req 2 for Project 3', 'Description for Req 2', 'Open', 30),
    (4, 'Req 1 for Project 4', 'Description for Req 1', 'Completed', 100),
    (4, 'Req 2 for Project 4', 'Description for Req 2', 'In Progress', 60);
```
api projects
```rust
use crate::db::DBManager;

use super::ApiError;

pub struct ProjectList {
    pub code: String,
    pub name: String,
    pub slug: String,
}

pub async fn project_list(db: &DBManager) -> Result<Vec<ProjectList>, ApiError> {
    let conn = db.conn().await?;

    let rows = conn.query("SELECT * FROM project", &[]).await?;

    let items: Vec<ProjectList> = rows
        .iter()
        .map(|row| ProjectList {
            code: row.get("code"),
            name: row.get("name"),
            slug: row.get("slug"),
        })
        .collect();

    Ok(items)
}
```
req api
```rust
use serde::Deserialize;
use tokio_postgres::types::ToSql;

use crate::db::DBManager;

use super::ApiError;

// Constants
const STATUS_NEW: &str = "new";
const PROGRESS: i32 = 0;

#[derive(Debug, Deserialize)]
pub struct RequirementCreateInput {
    pub requirement: String,
    pub description: String,
}

pub async fn create(
    db: &DBManager,
    project_id: &i64,
    input: &RequirementCreateInput,
) -> Result<i64, ApiError> {
    let conn = db.conn().await?;
    let rows = conn
        .query(
            "INSERT INTO requirement(project_id, requirement, description, status, progress) VALUES 
        ($1, $2, $3, $4, $5)  RETURNING id",
            &[
                &project_id,
                &input.requirement,
                &input.description,
                &STATUS_NEW,
                &PROGRESS
            ],
        )
        .await?;

    let Some(row) = rows.get(0) else {
        return Err(ApiError::Error(
            "Unable to create new requirement".to_string(),
        ));
    };

    Ok(row.get(0))
}

#[derive(Debug, Deserialize)]
pub struct RequirementUpdateInput {
    pub title: Option<String>,
    pub description: Option<String>,
    pub status: Option<String>,
    pub progress: Option<i32>,
}

pub async fn update_by_id(
    db: &DBManager,
    requirement_id: &i64,
    input: &RequirementUpdateInput,
) -> Result<bool, ApiError> {
    let conn = db.conn().await?;

    let mut set_clauses: Vec<String> = Vec::new();
    let mut params: Vec<&(dyn ToSql + Sync)> = Vec::new();

    if let Some(title) = &input.title {
        set_clauses.push(format!("title = ${}", params.len() + 1));
        params.push(title)
    }

    if let Some(status) = &input.status {
        set_clauses.push(format!("status = ${}", params.len() + 1));
        params.push(status)
    }

    if let Some(progress) = &input.progress {
        set_clauses.push(format!("progress = ${}", params.len() + 1));
        params.push(progress)
    }

    if let Some(description) = &input.description {
        set_clauses.push(format!("description = ${}", params.len() + 1));
        params.push(description)
    }

    if set_clauses.is_empty() {
        return Err(ApiError::Error(
            "Enter minimum one data to update".to_string(),
        ));
    }

    let query = format!(
        "UPDATE requirement SET {} WHERE id = ${}",
        set_clauses.join(", "),
        params.len() + 1
    );
    params.push(requirement_id);

    let val = conn.execute(&query, &params).await?;
    Ok(val != 0)
}

pub struct Requirement {
    pub requirement: String,
    pub description: String,
    pub status: String,
    pub progress: i32,
}

pub async fn get_list(db: &DBManager, slug: String) -> Result<Vec<Requirement>, ApiError> {
    let conn = db.conn().await?;

    let project_id = conn
        .query("SELECT id FROM project WHERE slug = $1", &[&slug])
        .await?;

    if project_id.is_empty() {
        return Err(ApiError::Error(format!("Slug does not exist {}", slug)));
    }

    let project_id: i64 = project_id.first().unwrap().get("id");

    let rows = conn
        .query(
            "SELECT * FROM requirements WHERE project_id = $1 ",
            &[&project_id],
        )
        .await?;

    let items: Vec<Requirement> = rows
        .iter()
        .map(|row| Requirement {
            requirement: row.get("requirement"),
            description: row.get("description"),
            status: row.get("status"),
            progress: row.get("progress"),
        })
        .collect();

    Ok(items)
}
```
web routes
```rust
use axum::{response::Html, Extension};
use sailfish::TemplateOnce;
use tracing::info;

use crate::{
    api::{self, projects::ProjectList},
    state::ExtAppState,
};

use super::{WebAuthUser, WebResult};

#[derive(TemplateOnce)]
#[template(path = "home.stpl")]
pub struct RenderProjectList {
    items: Vec<ProjectList>,
    no_data: Option<String>,
}

pub async fn handler_home(_user: WebAuthUser, Extension(app_state): ExtAppState) -> WebResult {
    info!("saf345243");
    let items = api::projects::project_list(&app_state.db).await?;
    info!("{}", items.len());
    if items.is_empty() {
        let ctx = RenderProjectList {
            items: vec![],
            no_data: Some("There is no projects available".to_string()),
        };
        return Ok(Html(ctx.render_once().unwrap()));
    }

    let ctx = RenderProjectList {
        items,
        no_data: None,
    };
    Ok(Html(ctx.render_once().unwrap()))
}

// pub async fn 
```
stpl
```html
<% for item in items.iter() { %>
    <div>
        <a href="/delete/<%= item.name %>" title="<%= item.name %>">
            <%= item.name %>
        </a>
    <div>
<% } %>
<% if no_data.is_some() { %>
    <div>
        <h3>
            <%= no_data.unwrap() %>
        <h3>
    </div>
<% } %>
```
