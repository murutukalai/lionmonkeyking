// https://docs.rs/axum/0.6.2/axum/extract/index.html#accessing-inner-errors

use std::error::Error;
use axum::{
    extract::{Json, rejection::JsonRejection},
    response::IntoResponse,
    http::StatusCode,
};
use serde_json::{json, Value};

async fn handler(
    result: Result<Json<Value>, JsonRejection>,
) -> Result<Json<Value>, (StatusCode, String)> {
    match result {
        // if the client sent valid JSON then we're good
        Ok(Json(payload)) => Ok(Json(json!({ "payload": payload }))),

        Err(err) => match err {
            JsonRejection::JsonDataError(err) => {
                Err(serde_json_error_response(err))
            }
            JsonRejection::JsonSyntaxError(err) => {
                Err(serde_json_error_response(err))
            }
            // handle other rejections from the `Json` extractor
            JsonRejection::MissingJsonContentType(_) => Err((
                StatusCode::BAD_REQUEST,
                "Missing `Content-Type: application/json` header".to_string(),
            )),
            JsonRejection::BytesRejection(_) => Err((
                StatusCode::INTERNAL_SERVER_ERROR,
                "Failed to buffer request body".to_string(),
            )),
            // we must provide a catch-all case since `JsonRejection` is marked
            // `#[non_exhaustive]`
            _ => Err((
                StatusCode::INTERNAL_SERVER_ERROR,
                "Unknown error".to_string(),
            )),
        },
    }
}

// attempt to extract the inner `serde_json::Error`, if that succeeds we can
// provide a more specific error
fn serde_json_error_response<E>(err: E) -> (StatusCode, String)
where
    E: Error + 'static,
{
    if let Some(serde_json_err) = find_error_source::<serde_json::Error>(&err) {
        (
            StatusCode::BAD_REQUEST,
            format!(
                "Invalid JSON at line {} column {}",
                serde_json_err.line(),
                serde_json_err.column()
            ),
        )
    } else {
        (StatusCode::BAD_REQUEST, "Unknown error".to_string())
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
        find_error_source(source)
    } else {
        None
    }
}
