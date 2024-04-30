```rust
pub async fn create_row(
    db: &DBConnection<'_>,
    table_name: &str,
    fields_map: HashMap<&str, &(dyn ToSql + Sync)>,
) -> Result<i64, DbError> {
    if fields_map.is_empty() {
        return Err(DbError::Error(
            "Unable to create a row with empty fields".to_string(),
        ));
    }

    let mut fields: Vec<&str> = vec![];
    let mut params: Vec<&(dyn ToSql + Sync)> = vec![];
    let mut dollar_values: Vec<String> = vec![];

    let mut dollar_value: i64 = 1;
    for (key, value) in fields_map {
        dollar_values.push(format!("${dollar_value}"));
        fields.push(key);
        params.push(value);
        dollar_value += 1;
    }

    let query = format!(
        "INSERT INTO {} ({}, id) VALUES ({}, ${}) RETURNING ID",
        table_name,
        fields.join(", "),
        dollar_values.join(", "),
        params.len() + 1
    );

    let mut loop_count = 1;
    let nano_id: i64;
    loop {
        let alphabet: [char; 10] = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
        let nano_id = nanoid::nanoid!(8, &alphabet)
            .parse::<i64>()
            .map_err(|err| DbError::Error(err.to_string()))?;

        if loop_count != 1 {
            params.remove(params.len() - 1);
        }
        params.push(&nano_id);

        let row = db.query_one(&query, &params).await;

        loop_count += 1;
        match row {
            Ok(row) => {
                return Ok(row.get::<_, i64>("id"));
            }
            Err(err) => {
                if err
                    .to_string()
                    .contains(format!("Key (id)=({nano_id}) already exists.").as_str())
                {
                    continue;
                } else {
                    return Err(DbError::PostgresError(err));
                }
            }
        };
    }
}
```
