To modify the example so that the output is a struct containing `id` and `msg`, you'll need to:

1. Define the struct.
2. Modify the `send_handler` to create and send this struct.
3. Adjust the `sse_handler` to handle and send the struct in the appropriate format.

Here's the updated code:

1. Add the necessary dependencies to your `Cargo.toml`:

```toml
[dependencies]
axum = "0.5"
tokio = { version = "1", features = ["full"] }
tower = "0.4"
hyper = { version = "0.14", features = ["full"] }
futures = "0.3"
tokio-tungstenite = "0.15"
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
```

2. Update the server code:

```rust
use axum::{
    extract::Extension,
    response::sse::{Event, KeepAlive, Sse},
    routing::get,
    Router,
};
use futures::{stream, SinkExt, StreamExt};
use hyper::Body;
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::{
    net::SocketAddr,
    sync::{Arc, Mutex},
};
use tokio::sync::broadcast;
use tokio_stream::wrappers::BroadcastStream;

#[derive(Serialize, Deserialize, Debug)]
struct Message {
    id: u32,
    msg: String,
}

type SharedState = Arc<Mutex<broadcast::Sender<Message>>>;

#[tokio::main]
async fn main() {
    // Create a broadcast channel for sending messages
    let (tx, _) = broadcast::channel::<Message>(100);
    let shared_state = Arc::new(Mutex::new(tx));

    // Build the Axum application
    let app = Router::new()
        .route("/sse", get(sse_handler))
        .route("/send", get(send_handler))
        .layer(Extension(shared_state));

    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));
    println!("Server running at http://{}", addr);

    axum::Server::bind(&addr)
        .serve(app.into_make_service())
        .await
        .unwrap();
}

async fn sse_handler(
    Extension(shared_state): Extension<SharedState>,
) -> Sse<impl futures::Stream<Item = Result<Event, std::convert::Infallible>>> {
    let rx = {
        let tx = shared_state.lock().unwrap().subscribe();
        BroadcastStream::new(tx)
    };

    let stream = rx.map(|msg| {
        let data = msg.unwrap_or_else(|_| Message { id: 0, msg: "".to_string() });
        let json_data = serde_json::to_string(&data).unwrap_or_else(|_| "".to_string());
        Ok(Event::default().data(json_data))
    });

    Sse::new(stream).keep_alive(KeepAlive::default())
}

async fn send_handler(
    Extension(shared_state): Extension<SharedState>,
) -> &'static str {
    let message = Message {
        id: 1,  // In a real application, you'd generate unique IDs
        msg: "Hello, world!".to_string(),
    };

    {
        let tx = shared_state.lock().unwrap();
        tx.send(message.clone()).unwrap();
    }

    // In a real application, you would send a browser notification here
    println!("Message sent: {:?}", message);

    "Message sent"
}
```

In this updated example:

1. We define a `Message` struct with `id` and `msg` fields.
2. The `send_handler` creates a `Message` instance and sends it via the broadcast channel.
3. The `sse_handler` subscribes to the broadcast channel, receives `Message` instances, serializes them to JSON, and sends them to the clients as SSE events.

You can now run the server with `cargo run`, open multiple tabs at `http://localhost:3000/sse`, and visit `http://localhost:3000/send` to send messages. Each tab will receive the messages with their `id` and `msg` fields.

---------------------------------------------------------------------------------------------------------------------
