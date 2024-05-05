status log 7.00 pm time set
```rust
let current_date = chrono::offset::Local::now().date_naive();
    let modified_on = NaiveDateTime::parse_from_str(
        format!("{} {}", current_date.format("%Y-%m-%d"), "19:00").as_str(),
        "%Y-%m-%d %H:%M",
    )
    .map_err(Error::new)?;

    // Update the open day-in status-log for current day
    db.execute(
        "UPDATE employee_status_log SET modified_on = $1, is_closed = true, status = 'day-out'
        WHERE status = 'day-in' AND is_closed = false AND DATE(created_on) = $2",
        &[&modified_on, &current_date],
    )
    .await
    .map_err(Error::new)?;
```

for leave sorting 
```rust
where_clauses.push(format!("DATE(start_date_time) >= ${}", params.len() + 1));
```
document preview 
```rust
pub async fn view(
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

    let content_type = match mime_guess::from_ext(&file_exe).first() {
        Some(mime) => mime.to_string(),
        None => "application/octet-stream".to_string(),
    };

    tracing::info!("Content-Type: {}", content_type);

    let headers = [
        (
            header::CONTENT_TYPE,
            format!("{}; charset=utf-8", content_type),
        ),
        (
            header::CONTENT_DISPOSITION,
            format!("inline; filename=\"{}.{}\"", file_name, file_exe),
        ),
    ];

    Ok((headers, result.bytes().await?))
}
```
