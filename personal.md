```rust
// Api - document

use serde::{Deserialize, Serialize};
use tokio_postgres::types::ToSql;
use tracing::info;

use super::{common, ApiError};
use crate::db::DBConnection;

#[derive(Debug, Deserialize)]
pub struct DocumentUpdateInput {
    filename: Option<String>,
    status: Option<String>,
}

// Constant
const STATUS_NEW: &str = "N";

pub async fn create(
    db: &DBConnection<'_>,
    project_id: i64,
    requirement_id: i64,
    filename: &String,
    size: i64,
    file_type: &String,
    path: &String,
) -> Result<i64, ApiError> {
    let count: i64 = db
        .query_one(
            "SELECT COUNT(id) as count FROM document WHERE name = $1 AND  path = $2",
            &[&filename, &path],
        )
        .await?
        .get("count");
    if count > 0 {
        return Err(ApiError::Error(format!(
            "File name \"{}\" already exist in this path \"{}\"",
            &filename, &path
        )));
    }

    let params: Vec<&(dyn ToSql + Sync)> = vec![
        &project_id,
        &requirement_id,
        &filename,
        &size,
        &file_type,
        &path,
        &STATUS_NEW,
    ];

    let rows = db
        .query(
            "INSERT INTO document (project_id, requirement_id, name, size, type, path, status)
             VALUES ($1, $2, $3, $4, $5, $6, $7) 
             RETURNING ID",
            &params,
        )
        .await?;

    let Some(row) = rows.get(0) else {
        return Err(ApiError::Error(
            "Unable to upload path in database".to_string(),
        ));
    };

    Ok(row.get(0))
}

#[derive(Debug, Serialize)]
pub struct DocList {
    pub id: i64,
    pub filename: String,
    pub size: String,
    pub file_type: String,
    pub path: String,
    pub status: String,
}

pub async fn get_list(
    db: &DBConnection<'_>,
    project_id: i64,
    requirement_id: i64,
    with_archive: bool,
) -> Result<Vec<DocList>, ApiError> {
    let mut query = r#"SELECT * FROM document 
                     WHERE project_id = $1 AND requirement_id = $2"#
        .to_string();

    if !with_archive {
        query += " AND status != 'A'"
    }

    query += " ORDER BY created_on";

    let rows = db.query(&query, &[&project_id, &requirement_id]).await?;

    if rows.is_empty() {
        return Ok(vec![]);
    }

    let items: Vec<DocList> = rows
        .iter()
        .map(|row| DocList {
            id: row.get("id"),
            filename: row.get("name"),
            size: human_bytes::human_bytes(row.get::<_, i64>("size") as f64),
            file_type: row.get("type"),
            path: row.get("path"),
            status: common::get_display_status(row.get("status")),
        })
        .collect();

    Ok(items)
}

pub async fn update_by_id(
    db: &DBConnection<'_>,
    project_id: i64,
    requirement_id: i64,
    document_id: i64,
    input: &DocumentUpdateInput,
) -> Result<bool, ApiError> {
    let count: i64 = db
        .query_one(
            "SELECT COUNT(id) as count FROM document 
             WHERE id = $1 AND project_id = $2 AND requirement_id = $3",
            &[&document_id, &project_id, &requirement_id],
        )
        .await?
        .get("count");
    if count == 0 {
        return Err(ApiError::Error(format!(
            "Document with id '{}' does not exist",
            document_id
        )));
    }

    let mut set_clauses: Vec<String> = Vec::new();
    let mut params: Vec<&(dyn ToSql + Sync)> = Vec::new();

    if let Some(name) = &input.filename {
        set_clauses.push(format!("name = ${}", params.len() + 1));
        params.push(name);
    }

    if let Some(status) = &input.status {
        set_clauses.push(format!("status = ${}", params.len() + 1));
        params.push(status);
    }

    if set_clauses.is_empty() {
        return Err(ApiError::Error(
            "Enter minimum one data to update".to_string(),
        ));
    }

    let query = format!(
        "UPDATE document SET {} WHERE id = ${} AND project_id = ${} AND requirement_id = ${}",
        set_clauses.join(", "),
        params.len() + 1,
        params.len() + 2,
        params.len() + 3
    );
    params.push(&document_id);
    params.push(&project_id);
    params.push(&requirement_id);

    let val = db.execute(&query, &params).await?;

    Ok(val != 0)
}

pub async fn get_by_id(
    db: &DBConnection<'_>,
    project_id: i64,
    requirement_id: i64,
    document_id: i64,
) -> Result<DocList, ApiError> {
    let rows = db
        .query(
            "SELECT * FROM document 
             WHERE id = $1 AND project_id = $2 AND requirement_id = $3",
            &[&document_id, &project_id, &requirement_id],
        )
        .await?;

    let Some(row) = rows.first() else {
        return Err(ApiError::Error(format!(
            "Document with id '{}' does not exist",
            requirement_id
        )));
    };

    Ok(DocList {
        id: row.get("id"),
        filename: row.get("name"),
        size: human_bytes::human_bytes(row.get::<_, i64>("size") as f64),
        file_type: row.get("type"),
        path: row.get("path"),
        status: row.get("status")
    })
}

// Route - Rest - Document

use axum::{
    extract::{Multipart, Path},
    Extension, Json,
};
use sailfish::TemplateOnce;
use serde::Serialize;
use std::path;
use std::{
    fs::{self, File},
    io::Write,
};
use tracing::info;

use super::{RestAuthUser, RestContentResponse, RestResult};
use crate::{
    api::{
        document::{self, update_by_id, DocList, DocumentUpdateInput},
        project::{self, ProjectInfo},
        requirement::{self, RequirementDetail},
    },
    route::rest::RestError,
    state::ExtAppState,
};

// Constant
const WRITE_FILE_PATH: &str = "public/requirement";
const READ_FILE_PATH: &str = "assets/requirement";

#[derive(TemplateOnce, Debug)]
#[template(path = "includes/list_document.stpl")]
pub struct TemplateContentDoc {
    role_is_admin: bool,
    role_is_qa: bool,
    project: ProjectInfo,
    requirement: RequirementDetail,
    docs: Vec<DocList>,
}

pub async fn handler_create(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
    Path((slug, req_id)): Path<(String, i64)>,
    mut multipart: Multipart,
) -> RestResult<RestContentResponse> {
    let db = app_state.db.conn().await?;
    let project = project::get_by_slug(&db, &slug).await.unwrap();

    // Creating a directory if not exist
    if !path::Path::new(&format!("./{WRITE_FILE_PATH}")).exists() {
        let Ok(_) = fs::create_dir(format!("./{WRITE_FILE_PATH}").as_str()) else {
            tracing::info!("Unable to create dir");
            return Err(RestError::Error("Unable to create dir".to_string()));
        };
    };

    let mut file_name: String = String::new();
    let mut file_type: String = String::new();
    let mut data_len: i64 = 0;
    let mut path: String = String::new();

    while let Some(mut field) = multipart.next_field().await.map_err(|error| {
        tracing::error!("Error getting next field: {error}");
        RestError::Error("INTERNAL_SERVER_ERROR".to_string())
    })? {
        let name = field
            .name()
            .map(ToString::to_string)
            .unwrap_or("name".to_owned());

        file_name = field
            .file_name()
            .map(ToString::to_string)
            .unwrap_or("file_name".to_owned());
        
        let Some(file_typ) = field.content_type().map(ToString::to_string) else {
            tracing::info!("We don't have a content type");
            return Err(RestError::Error("UNSUPPORTED_MEDIA_TYPE".to_string()));
        };

        info!{"file"};
        file_type = file_typ;

        let Some(file_extension) = file_type.split('/').last() else {
            return Err(RestError::Error("Unable to get file extension".to_string()));
        };

        let mut file = File::create(&format!("./{WRITE_FILE_PATH}/{file_name}")).map_err(|error| {
            tracing::error!("Error opening file for writing: {error}");
            RestError::Error("INTERNAL_SERVER_ERROR".to_string())
        })?;

        // Getting the file size
        data_len = 0;
        loop {
            let Some(data) = field.chunk().await.map_err(|error| {
                tracing::error!("Error getting chunk: {error}");
                RestError::Error("INTERNAL_SERVER_ERROR".to_string())
            })?
            else {
                tracing::info!("No more chunks");
                break;
            };

            tracing::info!("Processing field in multipart");

            data_len += data.len() as i64;

            file.write_all(&data).map_err(|error| {
                tracing::error!("Error writing chunk to file: {error}");
                RestError::Error("INTERNAL_SERVER_ERROR".to_string())
            })?;
        }

        tracing::info!(
            "name: {} - file_name: {} - data: {} - content type: {}",
            name,
            file_name,
            data_len,
            file_type
        );
        path = format!("{READ_FILE_PATH}/{file_name}");
    }

    let val = document::create(
        &db, project.id, req_id, &file_name, data_len, &file_type, &path,
    )
    .await?;

    let mut content: Option<String> = None;
    if val > 0 {
        let requirement = requirement::get_by_id(&db, project.id, req_id).await?;
        let docs = document::get_list(&db, project.id, req_id, true).await?;
        let ctx = TemplateContentDoc {
            role_is_admin: user.is_admin(),
            role_is_qa: user.is_qa(),
            project,
            requirement,
            docs,
        };
        content = Some(ctx.render_once().unwrap());
    }

    Ok(Json(RestContentResponse {
        success: val != 0,
        error: None,
        content,
    }))
}

// Delete

pub async fn handler_update(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
    Path((slug, req_id, document_id)): Path<(String, i64, i64)>,
    Json(input): Json<DocumentUpdateInput>,
) -> RestResult<RestContentResponse> {
    let db = app_state.db.conn().await?;
    let project = project::get_by_slug(&db, &slug).await?;

    let success = update_by_id(&db, project.id, req_id, document_id, &input).await?;
    info!(
        "{:?}",
        update_by_id(&db, project.id, req_id, document_id, &input).await
    );

    let mut content: Option<String> = None;
    if success {
        let requirement = requirement::get_by_id(&db, project.id, req_id).await?;
        let docs = document::get_list(&db, project.id, req_id, user.is_admin()).await?;
        let ctx = TemplateContentDoc {
            role_is_admin: user.is_admin(),
            role_is_qa: user.is_qa(),
            project,
            requirement,
            docs,
        };
        content = Some(ctx.render_once().unwrap());
    }

    Ok(Json(RestContentResponse {
        success,
        error: None,
        content,
    }))
}

#[derive(Serialize, Debug)]
pub struct RestDocResponse {
    success: bool,
    item: Option<DocList>,
    error: Option<String>,
}

pub async fn handler_get(
    _user: RestAuthUser,
    Extension(app_state): ExtAppState,
    Path((slug, req_id, doc_id)): Path<(String, i64, i64)>,
) -> RestResult<RestDocResponse> {
    let db = app_state.db.conn().await?;
    let project = project::get_by_slug(&db, &slug).await?;
    let item = document::get_by_id(&db, project.id, req_id, doc_id).await?;

    Ok(Json(RestDocResponse {
        success: true,
        item: Some(item),
        error: None,
    }))
}

// routes

.route(
            "/:slug/requirement/:requirement_id/document/upload",
            post(document::handler_create).route_layer(DefaultBodyLimit::disable()),
        )
        .route(
            "/:slug/requirement/:requirement_id/document/:id",
            post(document::handler_update),
        )
        .route(
            "/:slug/requirement/:requirement_id/document/:id",
            get(document::handler_get),
        )



```
