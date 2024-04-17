```rust
// no preview only download
pub async fn handler_download() -> impl IntoResponse {
    let cur_dir = env::current_dir().unwrap();
    let store = storage::create_store(cur_dir.to_str().unwrap().to_string().as_str()).unwrap();

    let body = storage::get_content(
        store,
        format!("/public/data/724f3238-f607-4669-b380-b4ea1e0f8d04.pdf").as_str(),
    )
    .await
    .unwrap();

    let headers = [
        (header::CONTENT_TYPE, "application/pdf; charset=utf-8"),
        (
            header::CONTENT_DISPOSITION,
            "attachment; filename=\"Cargo.pdf\"",
        ),
    ];

    (headers, body)
}
```

Reffered from &rarr; https://github.com/tokio-rs/axum/discussions/608
There is anoth simple way to impliment the content type to the header &rarr; https://www.shuttle.rs/launchpad/issues/2023-28-07-issue-05-Traits-Image-Processing


https://gist.github.com/samuelsilvadev/5ed9f8b634dca67c8bd0912e3032d5f7
