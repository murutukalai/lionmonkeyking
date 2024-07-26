use axum::{
    extract::Extension,
    response::IntoResponse,
    routing::{get, post},
    Router, Json,
};
use futures_util::stream::{self, Stream};
use hyper::{header, Response, StatusCode};
use serde::{Deserialize, Serialize};
use std::{
    collections::HashMap,
    net::SocketAddr,
    sync::{Arc, Mutex},
    time::Duration,
};
use tokio::sync::broadcast;
use tower_cookies::{CookieManagerLayer, Cookies};
use tower_sessions::{SessionLayer, SessionStore};
use uuid::Uuid;

#[tokio::main]
async fn main() {
    // Create a broadcast channel for sending notifications
    let (tx, _rx) = broadcast::channel(100);

    // Create a shared state
    let app_state = Arc::new(AppState {
        broadcaster: tx,
        sessions: SessionStore::new(),
        logged_in_users: Mutex::new(HashMap::new()),
    });

    // Create the router
    let app = Router::new()
        .route("/", get(index))
        .route("/login", post(login))
        .route("/notify", get(notify))
        .layer(Extension(app_state))
        .layer(SessionLayer::new(app_state.clone().sessions.clone()))
        .layer(CookieManagerLayer::new());

    // Run the server
    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));
    println!("Listening on http://{}", addr);
    axum::Server::bind(&addr)
        .serve(app.into_make_service())
        .await
        .unwrap();
}

// Application state
struct AppState {
    broadcaster: broadcast::Sender<(Uuid, String)>, // Send session ID with message
    sessions: SessionStore<Uuid>,
    logged_in_users: Mutex<HashMap<Uuid, String>>, // session ID to user name mapping
}

// Handle login and set a session
async fn login(
    Json(payload): Json<LoginRequest>,
    cookies: Cookies,
    Extension(state): Extension<Arc<AppState>>,
) -> Result<impl IntoResponse, StatusCode> {
    let session_id = Uuid::new_v4();
    state.sessions.insert(session_id, payload.username.clone());
    cookies.add(tower_cookies::Cookie::new("session_id", session_id.to_string()));

    // Add the user to the logged-in users map
    state
        .logged_in_users
        .lock()
        .unwrap()
        .insert(session_id, payload.username);

    Ok((StatusCode::OK, Json(LoginResponse { session_id })))
}

#[derive(Deserialize)]
struct LoginRequest {
    username: String,
}

#[derive(Serialize)]
struct LoginResponse {
    session_id: Uuid,
}

// Serve the SSE notification
async fn notify(
    Extension(state): Extension<Arc<AppState>>,
    cookies: Cookies,
) -> Result<impl IntoResponse, StatusCode> {
    let session_id = cookies
        .get("session_id")
        .and_then(|cookie| Uuid::parse_str(cookie.value()).ok())
        .ok_or(StatusCode::UNAUTHORIZED)?;

    // Check if the user is logged in
    let username = state
        .logged_in_users
        .lock()
        .unwrap()
        .get(&session_id)
        .cloned()
        .ok_or(StatusCode::UNAUTHORIZED)?;

    // Create an SSE stream
    let rx = state.broadcaster.subscribe();
    let stream = tokio_stream::wrappers::BroadcastStream::new(rx);
    let stream = stream.filter_map(move |result| {
        let session_id = session_id.clone();
        async move {
            match result {
                Ok((msg_session_id, msg)) if msg_session_id == session_id => {
                    Some(Ok::<_, Infallible>(format!("data: {}\n\n", msg).into()))
                }
                _ => None,
            }
        }
    });

    // Trigger notifications for this user every 5 seconds
    tokio::spawn(send_notifications(
        state.broadcaster.clone(),
        username.clone(),
        session_id,
    ));

    let response = Response::builder()
        .header(header::CONTENT_TYPE, "text/event-stream")
        .header(header::CACHE_CONTROL, "no-cache")
        .header(header::CONNECTION, "keep-alive")
        .body(hyper::Body::wrap_stream(stream))
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(response)
}

use std::convert::Infallible;
use tokio::stream::StreamExt;

// Simulate sending notifications
async fn send_notifications(
    broadcaster: broadcast::Sender<(Uuid, String)>,
    username: String,
    session_id: Uuid,
) {
    let mut interval = tokio::time::interval(Duration::from_secs(5));
    let mut counter = 0;
    loop {
        interval.tick().await;
        let message = format!(
            "Hello, {}! Personalized Notification #{}",
            username, counter
        );
        let _ = broadcaster.send((session_id, message));
        counter += 1;
    }
}

// Serve the index page
async fn index() -> impl IntoResponse {
    Response::builder()
        .header(header::CONTENT_TYPE, "text/html")
        .body(
            r#"
        <!doctype html>
        <html>
        <head>
            <title>Axum SSE Example</title>
        </head>
        <body>
            <h1>Axum SSE Example</h1>
            <form id="login-form">
                <label for="username">Username:</label>
                <input type="text" id="username" name="username" required>
                <button type="submit">Login</button>
            </form>
            <div id="notifications">
                <h2>Notifications</h2>
                <ul id="notification-list"></ul>
            </div>
            <script>
                document.getElementById('login-form').onsubmit = async function(event) {
                    event.preventDefault();
                    const username = document.getElementById('username').value;
                    const response = await fetch('/login', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ username })
                    });
                    const data = await response.json();
                    console.log('Logged in with session ID:', data.session_id);

                    const eventSource = new EventSource('/notify');
                    eventSource.onmessage = function(event) {
                        const listItem = document.createElement('li');
                        listItem.textContent = event.data;
                        document.getElementById('notification-list').appendChild(listItem);
                    };
                };
            </script>
        </body>
        </html>
        "#
            .into(),
        )
        .unwrap()
}
