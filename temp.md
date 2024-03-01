```rust
// Route -Rest - Document

use axum::{
    extract::{Multipart, Path},
    Extension, Json,
};
use sailfish::TemplateOnce;
use std::path;
use std::{
    fs::{self, File},
    io::Write,
};
use tracing::info;

use super::{RestAuthUser, RestContentResponse, RestResult};
use crate::{
    api::{
        document::{self, update_by_id, DocDetail, DocumentUpdateInput},
        project::{self, ProjectInfo},
        requirement::{self, RequirementDetail},
    },
    route::rest::RestError,
    state::ExtAppState,
};

// Constant
const FILE_WRITE_PATH: &str = "public/requirements";

#[derive(TemplateOnce)]
#[template(path = "includes/list_document.stpl")]
pub struct TemplateContentDoc {
    project: ProjectInfo,
    role_is_admin: bool,
    requirement: RequirementDetail,
    docs: Vec<DocDetail>,
}

pub async fn handler_create(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
    Path((slug, req_id)): Path<(String, i64)>,
    mut multipart: Multipart,
) -> RestResult<RestContentResponse> {
    let db = app_state.db.conn().await?;
    let project = project::get_by_slug(&db, &slug).await.unwrap();
    info!("sdf");

    // Creating a directory if not exist
    if !path::Path::new(&format!("./{FILE_WRITE_PATH}")).exists() {
        let Ok(_) = fs::create_dir(format!("./{FILE_WRITE_PATH}")) else {
            tracing::info!("Unable to create dir");
            return Err(RestError::Error("UNSUPPORTED_MEDIA_TYPE".to_string()));
        };
    };

    let mut file_name: String = String::new();
    let mut file_type: String = String::new();
    let mut data_len: i64 = 0;
    let mut path: String = String::new();
    let mut val: i64 = 0;

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
        file_type = file_typ;

        let mut file =
            File::create(&format!("./{FILE_WRITE_PATH}/{file_name}")).map_err(|error| {
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
        path = file_name.to_string();

        val = document::create(
            &db, project.id, req_id, &file_name, data_len, &file_type, &path,
        )
        .await?;
    }

    let mut content: Option<String> = None;
    if val > 0 {
        let requirement = requirement::get_by_id(&db, project.id, req_id).await?;
        let docs = document::get_list(&db, project.id, req_id, true).await?;
        let ctx = TemplateContentDoc {
            project,
            role_is_admin: user.is_admin(),
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

// Update

pub async fn handler_update(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
    Path((slug, req_id, document_id)): Path<(String, i64, i64)>,
    Json(input): Json<DocumentUpdateInput>,
) -> RestResult<RestContentResponse> {
    let db = app_state.db.conn().await?;
    let project = project::get_by_slug(&db, &slug).await.unwrap();

    let success = update_by_id(&db, project.id, req_id, document_id, &input).await?;
    let mut content: Option<String> = None;
    if success {
        let requirement = requirement::get_by_id(&db, project.id, req_id).await?;
        let docs = document::get_list(&db, project.id, req_id, true).await?;
        let ctx = TemplateContentDoc {
            project,
            role_is_admin: user.is_admin(),
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

```
