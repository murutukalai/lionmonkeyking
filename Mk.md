To create a robust Axum server capable of sending hundreds of messages efficiently when notifications are created, you can implement a system that handles a high volume of messages using Tokio and an efficient broadcast system. This example will include enhancements to handle many notifications and ensure scalability.

1. **Set up your Rust environment** (if not already done):
   Ensure you have Rust installed. If not, install it from [rustup.rs](https://rustup.rs/).

2. **Create a new project**:
   ```sh
   cargo new axum-sse-server
   cd axum-sse-server
   ```

3. **Add dependencies**:
   Update your `Cargo.toml` to include `axum`, `tokio`, `tokio-stream`, and `serde_json`:
   ```toml
   [dependencies]
   axum = "0.5"
   tokio = { version = "1", features = ["full"] }
   tokio-stream = "0.1"
   serde = { version = "1", features = ["derive"] }
   serde_json = "1"
   futures = "0.3"
   ```

4. **Implement the Axum server with SSE**:

   Create a file `src/main.rs` with the following content:
   ```rust
   use axum::{
       extract::Extension,
       response::sse::{Sse, Event},
       routing::get,
       Router,
   };
   use futures::{stream, Stream, StreamExt};
   use serde::Serialize;
   use std::{convert::Infallible, sync::Arc};
   use tokio::sync::{broadcast, RwLock};
   use tokio_stream::wrappers::BroadcastStream;
   use std::time::Duration;
   use tokio::time::interval;

   #[derive(Serialize, Clone)]
   struct Notification {
       id: usize,
       message: String,
   }

   struct AppState {
       tx: broadcast::Sender<Notification>,
       notifications: RwLock<Vec<Notification>>,
   }

   #[tokio::main]
   async fn main() {
       let (tx, _rx) = broadcast::channel(1000);
       let app_state = Arc::new(AppState {
           tx,
           notifications: RwLock::new(Vec::new()),
       });

       let app = Router::new()
           .route("/notifications", get(sse_handler))
           .route("/send", get(send_notification))
           .layer(Extension(app_state));

       axum::Server::bind(&"0.0.0.0:3000".parse().unwrap())
           .serve(app.into_make_service())
           .await
           .unwrap();
   }

   async fn sse_handler(
       Extension(app_state): Extension<Arc<AppState>>,
   ) -> Sse<impl Stream<Item = Result<Event, Infallible>>> {
       let rx = app_state.tx.subscribe();
       let stream = BroadcastStream::new(rx).map(|msg| {
           let msg = msg.unwrap();
           let data = serde_json::to_string(&msg).unwrap();
           Ok(Event::default().data(data))
       });

       Sse::new(stream)
   }

   async fn send_notification(
       Extension(app_state): Extension<Arc<AppState>>,
   ) -> &'static str {
       let mut notifications = app_state.notifications.write().await;

       // Simulate sending hundreds of notifications
       for i in 0..100 {
           let notification = Notification {
               id: notifications.len(),
               message: format!("Notification #{}", notifications.len() + 1),
           };
           notifications.push(notification.clone());
           app_state.tx.send(notification).unwrap();
           tokio::time::sleep(Duration::from_millis(10)).await;  // Throttle to avoid overwhelming
       }

       "100 Notifications sent"
   }
   ```

5. **Run the server**:
   ```sh
   cargo run
   ```

6. **Test the SSE**:
   Open your browser and navigate to `http://localhost:3000/notifications`. You should see a connection established, but no messages initially. In another tab, navigate to `http://localhost:3000/send` to send 100 notifications. You should then see the notifications appear in the first tab, streamed as they are sent.

This implementation is designed to handle sending hundreds of notifications efficiently. It includes a simple throttling mechanism to avoid overwhelming the server and clients. The use of `RwLock` ensures thread-safe access to the shared notification state, and `serde_json` is used for serializing notifications into JSON format for the SSE stream.
