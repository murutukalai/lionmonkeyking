```rust
// Main

use anyhow::Result;
use axum::{
    error_handling::HandleErrorLayer,
    extract::{Extension, Request},
    http::{
        header::{ACCEPT, AUTHORIZATION, CONTENT_TYPE},
        request::Parts,
        HeaderValue, Method, StatusCode,
    },
    middleware::{self, Next},
    response::{Redirect, Response},
    routing::get,
    BoxError, RequestExt,
};
use axum_helmet::{Helmet, HelmetLayer};
use session::AuthSession;
use shared::app_state;
use std::sync::Arc;
use tokio::signal;
use tower::ServiceBuilder;
use tower_http::{cors::CorsLayer, services::ServeDir, trace::TraceLayer};
use tower_sessions::{cookie::time::Duration, CachingSessionStore, Expiry, SessionManagerLayer};
use tower_sessions_moka_store::MokaStore;
use tracing::info;
use tracing_appender::{
    non_blocking::WorkerGuard,
    rolling::{RollingFileAppender, Rotation},
};

mod api;
mod route;
mod session;

fn init_tracing(env_is_live: bool) -> Result<WorkerGuard> {
    let file_appender = RollingFileAppender::builder()
        .rotation(Rotation::DAILY)
        .filename_prefix("app")
        .filename_suffix("log")
        .build("./logs")?;
    let (file_log, guard) = tracing_appender::non_blocking(file_appender);
    let filter = tracing_subscriber::EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| "app=debug".into());

    if env_is_live {
        let subscriber = tracing_subscriber::fmt()
            .with_env_filter(filter)
            .with_writer(file_log)
            .with_target(true)
            .finish();
        tracing::subscriber::set_global_default(subscriber)?;
    } else {
        let subscriber = tracing_subscriber::fmt()
            .with_env_filter(filter)
            .with_target(false)
            .finish();
        tracing::subscriber::set_global_default(subscriber)?;
    }

    Ok(guard)
}

#[tokio::main]
async fn main() -> Result<()> {
    // Env
    dotenvy::dotenv()?;

    let app_env = option_env!("APP_ENV").unwrap_or("staging");
    let server_host = std::env::var("APP_HOST").unwrap_or("127.0.0.1".to_string());
    let env_is_live = app_env == "live";

    // Logging - Tracing
    let _guard = init_tracing(env_is_live)?;

    // Database
    let app_config = shared::app_state::AppConfig::new()?;
    let db_config = shared::db::DBConfig::new()?;
    let manager = shared::db::DBManager::new(db_config).await?;

    // Cors
    let cors = CorsLayer::new()
        .allow_origin(app_config.site_url.parse::<HeaderValue>().unwrap())
        .allow_methods([Method::GET, Method::POST])
        .allow_credentials(true)
        .allow_headers([AUTHORIZATION, ACCEPT, CONTENT_TYPE]);

    // Session Storage
    let postgres_store = session_store::PostgresStore::new(manager.get_pool()).await;
    let _ = postgres_store.migrate().await;

    let moka_store = MokaStore::new(Some(50));
    let caching_store = CachingSessionStore::new(moka_store, postgres_store);
    let session_layer = SessionManagerLayer::new(caching_store)
        .with_secure(env_is_live)
        .with_expiry(Expiry::OnInactivity(Duration::hours(16)));

    // Authentication
    /* let auth = session::Auth::new(manager.get_pool()).await; */
    let auth_service = ServiceBuilder::new()
        .layer(HandleErrorLayer::new(|_: BoxError| async {
            StatusCode::BAD_REQUEST
        }))
        .layer(session::AuthServiceLayer::new(&manager));

    // App
    let app_state = Arc::new(app_state::AppState {
        db: manager,
        config: app_config.clone(),
    });
    let asset_service = ServeDir::new("public").precompressed_gzip();

    let app = route::build()
        .layer(Extension(app_state))
        .layer(auth_service)
        .layer(session_layer)
        .layer(cors)
        .layer(HelmetLayer::new(
            Helmet::new()
                .add(helmet_core::XContentTypeOptions::nosniff())
                .add(helmet_core::XFrameOptions::same_origin())
                .add(helmet_core::XXSSProtection::on().mode_block()),
        ))
        .layer(TraceLayer::new_for_http())
        .layer(middleware::from_fn(my_middleware))
        .nest_service("/assets", asset_service);

    info!("Server starting in {}:{}!", server_host, app_config.port);
    println!(
        "Server starting in port {}:{}!",
        server_host, app_config.port
    );

    // Start the server as service
    let server_host = format!("{}:{}", server_host, app_config.port);
    let listener = tokio::net::TcpListener::bind(server_host).await.unwrap();
    axum::serve(listener, app.into_make_service())
        .with_graceful_shutdown(shutdown_signal())
        .await
        .unwrap();

    Ok(())
}

async fn shutdown_signal() {
    let ctrl_c = async {
        signal::ctrl_c()
            .await
            .expect("Failed to install Ctrl + C handler");
    };

    #[cfg(unix)]
    let terminate = async {
        signal::unix::signal(signal::unix::SignalKind::terminate())
            .expect("failed to install signal handler")
            .recv()
            .await;
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => {},
        _ = terminate => {},
    }
}

async fn my_middleware(request: Request, next: Next) -> Result<Redirect, StatusCode> {
    let (mut parts, b) = request.into_parts();
    let parts: &mut Parts = &mut parts;
    if let Some(session) = parts.extensions.get::<AuthSession>() {
        if let Some(user) = session.user.clone() {
            if user.username == "admin" {
                return Ok(Redirect::to("/"));
            }
            return Ok(Redirect::to(parts.uri));
        }
    }
    Err(StatusCode::INTERNAL_SERVER_ERROR)
}

```
