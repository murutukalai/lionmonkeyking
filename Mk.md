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
