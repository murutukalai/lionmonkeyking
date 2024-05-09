rest insp.rs
```rust
// Rest - Design - Inspiration

use axum::{
    extract::{Multipart, Path},
    response::IntoResponse,
    Extension, Json,
};
use backend_api::{
    design::inspiration::{
        self, InspirationCreateInput, InspirationGetOptions, InspirationItem,
        InspirationUpdateInput,
    },
    DBConnection,
};
use sailfish::TemplateOnce;
use serde::Deserialize;

use crate::{
    route::{
        common,
        rest::{
            convert, RestAuthUser, RestCommonResponse, RestContentResponse, RestError, RestResult,
        },
    },
    state::ExtAppState,
};

#[derive(Debug, Clone, Deserialize)]
pub struct RestInspirationGetOptions {
    pub keyword: Option<String>,
    pub status: Option<String>,
}

struct InspirationDocumentInfo {
    title: String,
    file_type: String,
    file_path: String,
    thumbnail_path: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct RestInspirationUpdateInput {
    pub title: Option<String>,

    #[serde(default)]
    pub tags: Vec<String>,
}

#[derive(TemplateOnce)]
#[template(path = "includes/design/inspiration_list.stpl")]
pub struct TemplateInspirationList {
    list: Vec<InspirationItem>,
    has_edit_access: bool,
    has_approve_access: bool,
    has_archive_access: bool,
    has_delete_access: bool,
}

pub async fn handler_list(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
    Json(options): Json<RestInspirationGetOptions>,
) -> RestResult<RestContentResponse> {
    let db = app_state.db.conn().await?;
    let acl = user.get_acl();

    acl.check_privilege(&db, user.id, "design", "inspiration", "view", None)
        .await?;
    let api_input = InspirationGetOptions {
        keyword: convert::to_string_optional(&options.keyword),
        status: convert::to_string_optional(&options.status),
    };

    let list = inspiration::get_list(&db, &api_input).await?;
    let ctx = TemplateInspirationList {
        list,
        has_edit_access: acl.has_privilege("design", "inspiration", "edit", None),
        has_approve_access: acl.has_privilege("design", "inspiration", "approve", None),
        has_archive_access: acl.has_privilege("design", "inspiration", "archive", None),
        has_delete_access: acl.has_privilege("design", "inspiration", "delete", None),
    };

    Ok(Json(RestContentResponse {
        success: true,
        content: Some(ctx.render_once().unwrap()),
        error: None,
    }))
}

#[derive(TemplateOnce)]
#[template(path = "includes/design/inspiration_add_modal.stpl")]
pub struct TemplateInspirationAddModal;

pub async fn handler_get_create(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
) -> RestResult<RestContentResponse> {
    let db = app_state.db.conn().await?;
    let acl = user.get_acl();

    acl.check_privilege(&db, user.id, "design", "inspiration", "add", None)
        .await?;

    let ctx = TemplateInspirationAddModal;
    Ok(Json(RestContentResponse {
        success: true,
        error: None,
        content: Some(ctx.render_once().unwrap()),
    }))
}

pub async fn handler_create(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
    mut multipart: Multipart,
) -> RestResult<RestCommonResponse> {
    let db = app_state.db.conn().await?;

    user.acl
        .check_privilege(&db, user.id, "design", "inspiration", "add", None)
        .await?;

    let mut inspirations: Vec<InspirationDocumentInfo> = vec![];

    while let Some(mut field) = multipart.next_field().await.unwrap() {
        if let Some("file") = field.name() {
            if field.file_name().is_some() && Some("") != field.file_name() {
                let Some(file_typ) = field.content_type().map(ToString::to_string) else {
                    return Err(RestError::Error("Unsupported content type".to_string()));
                };

                match file_typ.as_str() {
                    "image/png" => "png",
                    "image/jpeg" => "jpg",
                    "image/webp" => "webp",
                    _ => {
                        return Err(RestError::Error("Unsupported media type".to_string()));
                    }
                };

                let store = common::storage::create().await?;
                let doc_infos = store
                    .create_documents(&mut field, "/design-inspiration")
                    .await?;

                let mut inspiration = InspirationDocumentInfo {
                    title: "".to_string(),
                    file_path: "".to_string(),
                    file_type: "".to_string(),
                    thumbnail_path: "".to_string(),
                };

                if let Some(doc) = doc_infos.first() {
                    inspiration.file_path = format!("{}/{}", doc.file_path, doc.file_name);
                }

                let file_name = if let Some(name) = field.file_name() {
                    name.to_string()
                } else {
                    "file".to_string()
                };

                inspiration.thumbnail_path = store
                    .create_thumbnail("/design-thumbnail", inspiration.file_path.as_str())
                    .await?;

                inspiration.title =
                    if let Some(title) = file_name.split('.').collect::<Vec<&str>>().first() {
                        title.to_string()
                    } else {
                        file_name.clone()
                    };
                inspiration.file_type = storage::content_type::to_type(&file_name)?;

                inspirations.push(inspiration);
            }
        }
    }

    for ele in inspirations.iter() {
        let api_input = InspirationCreateInput {
            created_by_id: user.id,
            created_by: user.name.to_owned(),
            title: ele.title.to_owned(),
            file_path: ele.file_path.to_owned(),
            file_type: ele.file_type.to_owned(),
            thumbnail_path: ele.thumbnail_path.to_owned(),
        };

        let _ = inspiration::create(&db, &api_input).await?;
    }

    Ok(Json(RestCommonResponse {
        success: !inspirations.is_empty(),
        error: None,
    }))
}

#[derive(TemplateOnce)]
#[template(path = "includes/design/inspiration_edit_modal.stpl")]
pub struct TemplateInspirationEditModal {
    item: InspirationItem,
    action_url: String,
}

pub async fn handler_get(
    db: &DBConnection<'_>,
    inspiration_id: i64,
    is_approve: bool,
) -> RestResult<RestContentResponse> {
    let item = inspiration::get_by_id(db, inspiration_id).await?;
    let action_url = if is_approve {
        format!("/api/design/inspiration/{}/approve", inspiration_id)
    } else {
        format!("/api/design/inspiration/{}", inspiration_id)
    };
    let ctx = TemplateInspirationEditModal { item, action_url };

    Ok(Json(RestContentResponse {
        success: true,
        error: None,
        content: Some(ctx.render_once().unwrap()),
    }))
}

pub async fn handler_get_approve(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
    Path(inspiration_id): Path<i64>,
) -> RestResult<RestContentResponse> {
    let db = app_state.db.conn().await?;
    let acl = user.get_acl();

    acl.check_privilege(&db, user.id, "design", "inspiration", "approve", None)
        .await?;

    handler_get(&db, inspiration_id, true).await
}

pub async fn handler_get_edit(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
    Path(inspiration_id): Path<i64>,
) -> RestResult<RestContentResponse> {
    let db = app_state.db.conn().await?;
    let acl = user.get_acl();

    acl.check_privilege(&db, user.id, "design", "inspiration", "edit", None)
        .await?;

    handler_get(&db, inspiration_id, false).await
}

pub async fn handler_update(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
    Path(inspiration_id): Path<i64>,
    Json(input): Json<RestInspirationUpdateInput>,
) -> RestResult<RestCommonResponse> {
    let db = app_state.db.conn().await?;

    user.get_acl()
        .check_privilege(&db, user.id, "design", "inspiration", "edit", None)
        .await?;

    let api_input = InspirationUpdateInput {
        title: input.title,
        tags: Some(input.tags),
    };

    let success = inspiration::update_by_id(&db, inspiration_id, &api_input, false).await?;

    Ok(Json(RestCommonResponse {
        success,
        error: None,
    }))
}

pub async fn handler_approve(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
    Path(inspiration_id): Path<i64>,
    Json(input): Json<RestInspirationUpdateInput>,
) -> RestResult<RestCommonResponse> {
    let db = app_state.db.conn().await?;

    user.get_acl()
        .check_privilege(&db, user.id, "design", "inspiration", "approve", None)
        .await?;

    let api_input = InspirationUpdateInput {
        title: input.title,
        tags: Some(input.tags),
    };

    let success = inspiration::update_by_id(&db, inspiration_id, &api_input, true).await?;

    Ok(Json(RestCommonResponse {
        success,
        error: None,
    }))
}

pub async fn handler_view(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
    Path(inspiration_id): Path<i64>,
) -> Result<impl IntoResponse, RestError> {
    let db = app_state.db.conn().await?;

    user.get_acl()
        .check_privilege(&db, user.id, "design", "inspiration", "view", None)
        .await?;

    let insp = inspiration::get_by_id(&db, inspiration_id).await?;
    let store = common::storage::create().await?;

    Ok(store.view(&insp.file_path).await?)
}

pub async fn handler_thumbnail_view(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
    Path(inspiration_id): Path<i64>,
) -> Result<impl IntoResponse, RestError> {
    let db = app_state.db.conn().await?;

    user.get_acl()
        .check_privilege(&db, user.id, "design", "inspiration", "view", None)
        .await?;

    let insp = inspiration::get_by_id(&db, inspiration_id).await?;
    let store = common::storage::create().await?;

    Ok(store.view(&insp.thumbnail_path).await?)
}

pub async fn handler_archive(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
    Path(inspiration_id): Path<i64>,
) -> RestResult<RestCommonResponse> {
    let db = app_state.db.conn().await?;

    user.acl
        .check_privilege(&db, user.id, "design", "inspiration", "archive", None)
        .await?;

    let success = inspiration::update_archive(&db, inspiration_id).await?;

    Ok(Json(RestCommonResponse {
        success,
        error: None,
    }))
}

pub async fn handler_delete(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
    Path(inspiration_id): Path<i64>,
) -> RestResult<RestCommonResponse> {
    let db = app_state.db.conn().await?;

    user.acl
        .check_privilege(&db, user.id, "design", "inspiration", "delete", None)
        .await?;

    let success = inspiration::delete_by_id(&db, inspiration_id).await?;

    Ok(Json(RestCommonResponse {
        success,
        error: None,
    }))
}
```
stora lib.rs
```rust
// Libs - Storage

use axum::{extract::multipart::Field, http::header, response::IntoResponse};
use futures::stream::StreamExt;
use object_store::{PutPayload, WriteMultipart};

use std::io::Cursor;
#[cfg(not(feature = "with-s3"))]
use std::path;

#[cfg(not(feature = "with-s3"))]
use object_store::{self, local::LocalFileSystem, path::Path, ObjectStore};

#[cfg(feature = "with-s3")]
use object_store::{
    self,
    aws::{AmazonS3, AmazonS3Builder},
    path::Path,
    ObjectStore,
};

pub mod content_type;

#[derive(thiserror::Error, Debug)]
pub enum DocumentStoreError {
    // Common Error
    #[error("Error: {0}")]
    Error(String),

    // Object Store Error
    #[error("Parse error: {0}")]
    ObjectError(#[from] object_store::Error),
}

#[cfg(feature = "with-s3")]
pub struct DocumentStore {
    store: AmazonS3,
    _store_type: String,
    _initial_path: String,
}

#[cfg(not(feature = "with-s3"))]
pub struct DocumentStore {
    store: LocalFileSystem,
    _store_type: String,
    _initial_path: String,
}

#[derive(Debug, Clone)]
pub struct DocumentInfo {
    pub file_path: String,
    pub file_name: String,
    pub size: String,
}

impl DocumentStore {
    #[cfg(feature = "with-s3")]
    pub fn create(initial_path: &str) -> Result<DocumentStore, DocumentStoreError> {
        Ok(DocumentStore {
            store: AmazonS3Builder::from_env()
                .with_bucket_name(initial_path)
                .build()?,
            _store_type: "S3".to_string(),
            _initial_path: initial_path.to_string(),
        })
    }

    #[cfg(not(feature = "with-s3"))]
    pub fn create(initial_path: &str) -> Result<DocumentStore, DocumentStoreError> {
        let path = path::Path::new(initial_path);
        Ok(DocumentStore {
            store: LocalFileSystem::new_with_prefix(path)?,
            _store_type: "Local Store".to_string(),
            _initial_path: initial_path.to_string(),
        })
    }

    pub async fn get_list(&self, path: &str) -> Result<Vec<DocumentInfo>, DocumentStoreError> {
        let prefix = Path::from(path);
        let mut list_stream = self.store.list(Some(&prefix));
        let mut items: Vec<DocumentInfo> = vec![];
        while let Some(meta) = list_stream.next().await.transpose()? {
            let file_name = if let Some(name) = meta.location.filename() {
                name.to_string()
            } else {
                String::new()
            };

            items.push(DocumentInfo {
                file_path: meta.location.to_string(),
                file_name,
                size: bytesize::ByteSize::to_string_as(
                    &bytesize::ByteSize::b(meta.size as u64),
                    true,
                )
                .to_string(),
            });
        }
        Ok(items)
    }

    pub async fn create_documents(
        &self,
        field: &mut Field<'_>,
        path: &str,
    ) -> Result<Vec<DocumentInfo>, DocumentStoreError> {
        let mut doc_info: Vec<DocumentInfo> = vec![];

        let Some(_) = field.content_type().map(ToString::to_string) else {
            return Err(DocumentStoreError::Error(
                "Unsupported content type".to_string(),
            ));
        };

        let Some(file_name) = field.file_name().map(ToString::to_string) else {
            return Err(DocumentStoreError::Error(
                "Unable to get the file name".to_string(),
            ));
        };

        let Some(file_exe) = file_name.split('.').last() else {
            return Err(DocumentStoreError::Error(
                "Unable to fetch file extension".to_string(),
            ));
        };
        let file_exe = file_exe.to_lowercase();

        let mut data_len = 0;
        let doc_id = uuid::Uuid::new_v4();
        let file_path = Path::from(format!("{}/{}.{}", path, doc_id, file_exe));
        let upload = self.store.put_multipart(&file_path).await?;
        let mut writer = WriteMultipart::new(upload);

        loop {
            let Some(data) = field
                .chunk()
                .await
                .map_err(|err| DocumentStoreError::Error(err.to_string()))?
            else {
                break;
            };

            data_len += data.len() as u64;
            writer.write(&data);
        }

        doc_info.push(DocumentInfo {
            file_path: path.to_string(),
            file_name: format!("{}.{}", doc_id, file_exe),
            size: bytesize::ByteSize::to_string_as(&bytesize::ByteSize::b(data_len), true)
                .to_string(),
        });

        writer
            .finish()
            .await
            .map_err(|err| DocumentStoreError::Error(err.to_string()))?;

        Ok(doc_info)
    }

    pub async fn get_content(&self, path: &str) -> Result<bytes::Bytes, DocumentStoreError> {
        let path = Path::from(path);
        let result = self.store.get(&path).await?;
        Ok(result.bytes().await?)
    }

    pub async fn delete(&self, path: &str) -> Result<(), DocumentStoreError> {
        let path = Path::from(path);
        Ok(self.store.delete(&path).await?)
    }

    pub async fn download(
        &self,
        path: &str,
        file_name: &str,
    ) -> Result<impl IntoResponse, DocumentStoreError> {
        let file_path = Path::from(path);
        let result = self.store.get(&file_path).await?;

        let Some(file_exe) = path.split('.').last() else {
            return Err(DocumentStoreError::Error(
                "Unable to fetch file extension".to_string(),
            ));
        };
        let file_exe = file_exe.to_lowercase();
        let mut mime = "application/octet-stream;".to_string();
        if let Some(val) = mime_guess::from_ext(file_exe.as_str()).first() {
            mime = format!("{}/{};", val.type_(), val.subtype());
        }

        let headers = [
            (header::CONTENT_TYPE, format!("{}charset=utf-8", mime)),
            (
                header::CONTENT_DISPOSITION,
                format!("attachment; filename=\"{}.{}\"", file_name, file_exe).to_owned(),
            ),
        ];

        Ok((headers, result.bytes().await?))
    }

    pub async fn view(&self, path: &str) -> Result<impl IntoResponse, DocumentStoreError> {
        let file_path = Path::from(path);
        let result = self.store.get(&file_path).await?;

        let Some(file_exe) = path.split('.').last() else {
            return Err(DocumentStoreError::Error(
                "Unable to fetch file extension".to_string(),
            ));
        };
        let file_exe = file_exe.to_lowercase();
        let mut mime = "".to_string();
        if let Some(val) = mime_guess::from_ext(file_exe.as_str()).first() {
            mime = format!("{}/{};", val.type_(), val.subtype());
        }

        let headers = [
            (header::CONTENT_TYPE, format!("{}charset=utf-8", mime)),
            /* (
                header::CONTENT_DISPOSITION,
                format!("inline; filename=\"{}.{}\"", file_name, file_exe).to_owned(),
            ),*/
        ];

        Ok((headers, result.bytes().await?))
    }

    pub async fn create_thumbnail(
        &self,
        path: &str,
        main_file_path: &str,
    ) -> Result<String, DocumentStoreError> {
        let doc_id = uuid::Uuid::new_v4();
        let file_path = Path::from(format!("{}/{}.png", path, doc_id));

        let img = image::load_from_memory(&self.get_content(main_file_path).await?)
            .map_err(|err| DocumentStoreError::Error(err.to_string()))?;
        let resized_img = img.resize(100, 100, image::imageops::FilterType::Triangle);
        let mut resized_bytes: Vec<u8> = Vec::new();
        resized_img
            .write_to(
                &mut Cursor::new(&mut resized_bytes),
                image::ImageFormat::Png,
            )
            .expect("Failed to write image");

        let payload = PutPayload::from_bytes(resized_img.into_bytes().into());
        self.store.put(&file_path, payload).await.unwrap();

        Ok(file_path.to_string())
    }
}

```
