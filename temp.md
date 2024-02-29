```rust
let mut due_date: Option<NaiveDate> = None;
    if let Some(input_due_date) = input.due_date {
        if input_due_date.is_empty() {
            due_date = Some(chrono::Local::now().naive_local().into());
        } else {
            due_date = convert::to_date_optional(&Some(input_due_date), "Unable to convert due_date")?;
        }
    };
```
