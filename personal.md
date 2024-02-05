```rust
use std::{fs::File, io::Write};
use tracing::{info, Level};

use axum::{
    extract::{DefaultBodyLimit, Multipart}, http::StatusCode, response::{Html, Redirect}, routing::{get, post}, Router
};

pub async fn upload(mut multipart: Multipart) -> Result<StatusCode, StatusCode> {
    while let Some(mut field) = multipart.next_field().await.map_err(|error| {
        tracing::error!("Error getting next field: {error}");
        StatusCode::INTERNAL_SERVER_ERROR
    })? {
        let name = field
            .name()
            .map(ToString::to_string)
            .unwrap_or("name".to_owned());
        let file_name = field
            .file_name()
            .map(ToString::to_string)
            .unwrap_or("file_name".to_owned());
        // let file_size = field.
        let Some(file_type) = field.content_type().map(ToString::to_string) else {
            tracing::info!("we don't have a content type :(");
            break;
        };

        let file_extension = file_type.split('/').last().unwrap();

        // match file_type.as_str() {
        //     "image/png" => "png",
        //     "image/mp4" => "mp4",
        //     _ => {
        //         tracing::error!("got a file extension we don't know about");
        //         return Err(StatusCode::UNSUPPORTED_MEDIA_TYPE);
        //     }
        // };

        // let data = field.bytes().await.map_err(|error| {
        //     tracing::error!("Error get field bytes: {error}");
        //     StatusCode::INTERNAL_SERVER_ERROR
        // })?;

        // inside this one field we need to get the chunks until there are no more

        let mut file =
            File::create(&format!("../upload/{name}.{file_extension}")).map_err(|error| {
                tracing::error!("error opening file for writing: {error}");
                StatusCode::INTERNAL_SERVER_ERROR
            })?;

            let mut data_len = 0;

            loop {
                let Some(data) = field.chunk().await.map_err(|error| {
                    tracing::error!("Error getting chunk: {error}");
                    StatusCode::INTERNAL_SERVER_ERROR
                })?
                else {
                    tracing::info!("no more chunks");
                    break;
                };
                
                tracing::info!("processing field in multipart");
                tracing::info!(
                    "name: {name} - file_name: {file_name} - data: {} - content type: {file_type}",
                    data.len()
                );

                data_len += data.len();
                
                file.write_all(&data).map_err(|error| {
                    tracing::error!("Error writing chunk to file: {error}");
                    StatusCode::INTERNAL_SERVER_ERROR
                })?;
            }
            info!("{}",data_len);
        }
        
    Ok(StatusCode::OK)
    // Ok(Redirect::temporary("/"))
}
// let app = Router::new().route("/upload", post(upload));

#[tokio::main]
async fn main() {
    let subscriber = tracing_subscriber::FmtSubscriber::builder()
        // all spans/events with a level higher than TRACE (e.g, debug, info, warn, etc.)
        // will be written to stdout.
        .with_max_level(Level::TRACE)
        // builds the subscriber.
        .finish();

    tracing::subscriber::set_global_default(subscriber).expect("setting default subscriber failed");

    // build our application with a single route
    // let app = Router::new().route("/", get(|| async { "Hello, World!" }));
    let app = Router::new()
        .route("/", get(home_handler))
    .route(
        "/upload",
        post(upload).route_layer(DefaultBodyLimit::disable()),
    );

    // run our app with hyper, listening globally on port 3000
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    info!("listening to server in port 3000");
    axum::serve(listener, app).await.unwrap();
}


async fn home_handler() -> Html<String> {
    Html("Home page".to_string())
}

```


### Remove file

```rust
#![allow(unused)]
use std::fs;

fn main() -> std::io::Result<()> {
    fs::remove_file("a.txt")?;
    Ok(())
}

```

### Download file

```rust
pub async fn download(state: State<AppState>, 
                      Path(path): Path<String>) -> impl IntoResponse
{
    let data = b"your data";
    let stream = ReaderStream::new(&data[..]);
    let body = StreamBody::new(stream);
    let headers = [
        (header::CONTENT_TYPE, "text/toml; charset=utf-8"),
        (
            header::CONTENT_DISPOSITION,
            "attachment; filename=\"YourFileName.txt\"",
        ),
    ];
    (headers, body).into_response()
}
```
