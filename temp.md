```rust
// Route - REST Api

use crate::{db::DbError, session::AuthSession};
use anyhow::Result;
use axum::{
    async_trait,
    extract::{rejection::JsonRejection, FromRequestParts},
    http::{request::Parts, StatusCode},
    response::{IntoResponse, Response},
    Json, Router,
};
use backend_api::ApiError;
use serde::Serialize;
use serde_json::json;
use std::error::Error;

use super::Acl;

mod admin;
mod common;
mod company;
mod convert;
mod hrms;
mod security;

pub fn build() -> Router {
    Router::new()
        .merge(common::build())
        .nest("/security", security::build())
        .nest("/hrms", hrms::build())
        .nest("/admin", admin::build())
        .nest("/company", company::build())
}

// Error
pub(crate) type RestResult<T> = Result<Json<T>, RestError>;

#[derive(thiserror::Error, Debug)]
pub enum RestError {
    // Common Rest Error
    #[error("Error: {0}")]
    Error(String),

    /// Unauthorized Error
    #[error("Unauthorized")]
    Unauthorized,

    /// A Json error
    #[error("Json error: {0}")]
    Unprocessable(#[from] JsonRejection),

    /// A Db Error
    #[error("Db error: {0}")]
    DbError(#[from] DbError),

    /// An Api error
    #[error("Error: {0}")]
    Api(#[from] ApiError),
}

impl RestError {
    fn get_api_status_code(err: &ApiError) -> StatusCode {
        match err {
            ApiError::Error(_) => StatusCode::INTERNAL_SERVER_ERROR,
            _ => StatusCode::INTERNAL_SERVER_ERROR,
        }
    }

    fn json_match_error(err: JsonRejection) -> (StatusCode, String) {
        match err {
            JsonRejection::JsonDataError(err) => Self::serde_json_error_response(err),
            JsonRejection::JsonSyntaxError(err) => Self::serde_json_error_response(err),
            // handle other rejections from the `Json` extractor
            JsonRejection::MissingJsonContentType(_) => (
                StatusCode::BAD_REQUEST,
                "Missing `Content-Type: application/json` header".to_string(),
            ),
            JsonRejection::BytesRejection(_) => (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Failed to buffer request body".to_string(),
            ),
            // we must provide a catch-all case since `JsonRejection` is marked
            // `#[non_exhaustive]`
            _ => (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Unknown error".to_string(),
            ),
        }
    }

    // attempt to extract the inner `serde_json::Error`, if that succeeds we can
    // provide a more specific error
    fn serde_json_error_response<E>(err: E) -> (StatusCode, String)
    where
        E: Error + 'static,
    {
        if let Some(serde_json_err) = Self::find_error_source::<serde_json::Error>(&err) {
            (
                StatusCode::BAD_REQUEST,
                format!(
                    "Invalid JSON at line {} column {}",
                    serde_json_err.line(),
                    serde_json_err.column()
                ),
            )
        } else {
            (StatusCode::BAD_REQUEST, err.to_string())
        }
    }

    // attempt to downcast `err` into a `T` and if that fails recursively try and
    // downcast `err`'s source
    fn find_error_source<'a, T>(err: &'a (dyn Error + 'static)) -> Option<&'a T>
    where
        T: Error + 'static,
    {
        if let Some(err) = err.downcast_ref::<T>() {
            Some(err)
        } else if let Some(source) = err.source() {
            Self::find_error_source(source)
        } else {
            None
        }
    }
}

impl IntoResponse for RestError {
    fn into_response(self) -> Response {
        let (status, body) = match self {
            RestError::Error(_) => (StatusCode::ACCEPTED, self.to_string()),
            RestError::Unauthorized => (StatusCode::UNAUTHORIZED, self.to_string()),
            RestError::Unprocessable(err) => RestError::json_match_error(err),
            RestError::DbError(err) => (StatusCode::INTERNAL_SERVER_ERROR, err.to_string()),
            RestError::Api(ref err) => (RestError::get_api_status_code(err), self.to_string()),
        };
        (
            status,
            Json(json!({
                "success": false,
                "error": body,
            })),
        )
            .into_response()
    }
}

// Common Response
#[derive(Serialize, Debug)]
pub struct RestCommonResponse {
    pub success: bool,
    pub error: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct RestContentResponse {
    pub success: bool,
    pub error: Option<String>,
    pub content: Option<String>,
}

// Rest Auth User
#[derive(Debug, Clone)]
pub struct RestAuthUser {
    pub id: i64,
    pub username: String,
    pub name: String,
    pub acl: Acl,
}

#[async_trait]
impl<S> FromRequestParts<S> for RestAuthUser
where
    S: Sync + Send,
{
    type Rejection = RestError;

    async fn from_request_parts(parts: &mut Parts, _state: &S) -> Result<Self, Self::Rejection> {
        if let Some(session) = parts.extensions.get::<AuthSession>() {
            if let Some(user) = session.user.clone() {
                return Ok(RestAuthUser {
                    id: user.id,
                    username: user.username,
                    name: user.name,
                    acl: user.acl,
                });
            }
        }

        Err(RestError::Unauthorized)
    }
}

```

```rust
pub async fn handle_create(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
    result: Result<Json<PrivilegeCreateInput>, JsonRejection>,
) -> RestResult<RestCommonResponse> {
    let input = result?.0;
    let db = app_state.db.conn().await?;
```
