### db 
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
        "INSERT INTO {} ({}) VALUES ({}) RETURNING ID",
        table_name,
        fields.join(", "),
        dollar_values.join(", ")
    );

    let id: i64 = db.query_one(&query, &params).await?.get("id");

    Ok(id)
}

pub enum RustDataType {
    I8(i8),
    I16(i16),
    I32(i32),
    I64(i64),
    I128(i128),
    U32(u32),
    F32(f32),
    F64(f64),
    Bool(bool),
    Str(String),
    ToNaiveDate(NaiveDate),
    ToNaiveDateTime(NaiveDateTime),
    OptI8(Option<i8>),
    OptI16(Option<i16>),
    OptI32(Option<i32>),
    OptI64(Option<i64>),
    OptU32(Option<u32>),
    OptF32(Option<f32>),
    OptF64(Option<f64>),
    OptBool(Option<bool>),
    OptStr(Option<String>),
    OptToNaiveDate(Option<NaiveDate>),
    OptToNaiveDateTime(Option<NaiveDateTime>),
}

pub async fn update_row(
    db: &DBConnection<'_>,
    table_name: &str,
    set_clauses: HashMap<&str, &RustDataType>,
    where_class: HashMap<&str, &(dyn ToSql + Sync)>,
) -> Result<bool, DbError> {
    if set_clauses.is_empty() || where_class.is_empty() {
        return Err(DbError::Error(
            "Unable to update a row with empty fields".to_string(),
        ));
    }

    let mut params: Vec<&(dyn ToSql + Sync)> = vec![];
    let mut set_fields: Vec<String> = vec![];
    let mut where_fields: Vec<String> = vec![];

    let mut dollar_value: i64 = 1;
    for (key, _) in set_clauses.iter() {
        match set_clauses.get(key) {
            Some(RustDataType::I8(val)) => {
                set_fields.push(format!("{key} = ${dollar_value}"));
                params.push(val);
                dollar_value += 1;
            }
            Some(RustDataType::I16(val)) => {
                set_fields.push(format!("{key} = ${dollar_value}"));
                params.push(val);
                dollar_value += 1;
            }
            Some(RustDataType::I32(val)) => {
                set_fields.push(format!("{key} = ${dollar_value}"));
                params.push(val);
                dollar_value += 1;
            }
            Some(RustDataType::I64(val)) => {
                set_fields.push(format!("{key} = ${dollar_value}"));
                params.push(val);
                dollar_value += 1;
            }
            Some(RustDataType::U32(val)) => {
                set_fields.push(format!("{key} = ${dollar_value}"));
                params.push(val);
                dollar_value += 1;
            }
            Some(RustDataType::F32(val)) => {
                set_fields.push(format!("{key} = ${dollar_value}"));
                params.push(val);
                dollar_value += 1;
            }
            Some(RustDataType::F64(val)) => {
                set_fields.push(format!("{key} = ${dollar_value}"));
                params.push(val);
                dollar_value += 1;
            }
            Some(RustDataType::Bool(val)) => {
                set_fields.push(format!("{key} = ${dollar_value}"));
                params.push(val);
                dollar_value += 1;
            }
            Some(RustDataType::Str(val)) => {
                set_fields.push(format!("{key} = ${dollar_value}"));
                params.push(val);
                dollar_value += 1;
            }
            Some(RustDataType::ToNaiveDate(val)) => {
                set_fields.push(format!("{key} = ${dollar_value}"));
                params.push(val);
                dollar_value += 1;
            }
            Some(RustDataType::ToNaiveDateTime(val)) => {
                set_fields.push(format!("{key} = ${dollar_value}"));
                params.push(val);
                dollar_value += 1;
            }
            Some(RustDataType::OptI8(val)) => {
                if let Some(val) = val {
                    set_fields.push(format!("{key} = ${dollar_value}"));
                    params.push(val);
                    dollar_value += 1;
                }
            }
            Some(RustDataType::OptI16(val)) => {
                if let Some(val) = val {
                    set_fields.push(format!("{key} = ${dollar_value}"));
                    params.push(val);
                    dollar_value += 1;
                }
            }
            Some(RustDataType::OptI32(val)) => {
                if let Some(val) = val {
                    set_fields.push(format!("{key} = ${dollar_value}"));
                    params.push(val);
                    dollar_value += 1;
                }
            }
            Some(RustDataType::OptI64(val)) => {
                if let Some(val) = val {
                    set_fields.push(format!("{key} = ${dollar_value}"));
                    params.push(val);
                    dollar_value += 1;
                }
            }
            Some(RustDataType::OptU32(val)) => {
                if let Some(val) = val {
                    set_fields.push(format!("{key} = ${dollar_value}"));
                    params.push(val);
                    dollar_value += 1;
                }
            }
            Some(RustDataType::OptF32(val)) => {
                if let Some(val) = val {
                    set_fields.push(format!("{key} = ${dollar_value}"));
                    params.push(val);
                    dollar_value += 1;
                }
            }
            Some(RustDataType::OptF64(val)) => {
                if let Some(val) = val {
                    set_fields.push(format!("{key} = ${dollar_value}"));
                    params.push(val);
                    dollar_value += 1;
                }
            }
            Some(RustDataType::OptBool(val)) => {
                if let Some(val) = val {
                    set_fields.push(format!("{key} = ${dollar_value}"));
                    params.push(val);
                    dollar_value += 1;
                }
            }
            Some(RustDataType::OptStr(val)) => {
                if let Some(val) = val {
                    set_fields.push(format!("{key} = ${dollar_value}"));
                    params.push(val);
                    dollar_value += 1;
                }
            }
            Some(RustDataType::OptToNaiveDate(val)) => {
                if let Some(val) = val {
                    set_fields.push(format!("{key} = ${dollar_value}"));
                    params.push(val);
                    dollar_value += 1;
                }
            }
            Some(RustDataType::OptToNaiveDateTime(val)) => {
                if let Some(val) = val {
                    set_fields.push(format!("{key} = ${dollar_value}"));
                    params.push(val);
                    dollar_value += 1;
                }
            }
            _ => {
                return Err(DbError::Error(format!(
                    "Unable to fetch the data type of field '{key}'"
                )));
            }
        }
    }

    for (key, value) in where_class {
        where_fields.push(format!("{key} = ${dollar_value}"));
        params.push(value);
        dollar_value += 1;
    }

    let query = format!(
        "UPDATE {} SET (modified_on = current_timestamp, {}) WHERE {}",
        table_name,
        set_fields.join(", "),
        where_fields.join(" AND ")
    );
    let id: u64 = db.execute(&query, &params).await?;

    Ok(id != 0)
}

pub async fn delete_row(
    db: &DBConnection<'_>,
    table_name: &str,
    where_class: HashMap<&str, &(dyn ToSql + Sync)>,
) -> Result<bool, DbError> {
    if where_class.is_empty() {
        return Err(DbError::Error(
            "Unable to delete a row with empty fields".to_string(),
        ));
    }
    let mut params: Vec<&(dyn ToSql + Sync)> = vec![];
    let mut where_fields: Vec<String> = vec![];

    let mut dollar_value: i64 = 1;
    for (key, value) in where_class {
        where_fields.push(format!("{key} = ${dollar_value}"));
        params.push(value);
        dollar_value += 1;
    }

    let query = format!(
        "DELETE FROM {} ({}) ",
        table_name,
        where_fields.join(" AND ")
    );
    let id: u64 = db.execute(&query, &params).await?;

    Ok(id != 0)
}

#[cfg(test)]
mod test {
    use chrono::NaiveDate;
    use std::collections::HashMap;
    use tokio_postgres::types::ToSql;

    use crate::{db::create_row, initialize_db};

    #[tokio::test]
    async fn test_create_row() {
        let manager = initialize_db().await;
        let db = manager.conn().await.unwrap();

        let string: &(dyn ToSql + Sync) = &"abcd".to_owned();
        let date: &(dyn ToSql + Sync) = &NaiveDate::from_ymd_opt(2024, 3, 1).unwrap().to_owned();
        let number: &(dyn ToSql + Sync) = &123.to_owned();
        let val: i16 = 16;
        let small_number: &(dyn ToSql + Sync) = &val.to_owned();
        let val: i64 = 231;
        let big_number: &(dyn ToSql + Sync) = &val.to_owned();
        let val: f64 = 231.23;
        let float: &(dyn ToSql + Sync) = &val.to_owned();

        let fields_map: HashMap<&str, &(dyn ToSql + Sync)> = HashMap::from([
            ("string", string),
            ("date", date),
            ("number", number),
            ("small_number", small_number),
            ("big_number", big_number),
            ("float", float),
            ("bool", &true),
        ]);

        let id = create_row(&db, "test_db", fields_map).await.unwrap();

        // Getting the project id of above given key
        let db_row = db
            .query_one("SELECT * FROM test_db WHERE id = $1", &[&id])
            .await
            .unwrap();

        // Verify - name
        assert_eq!("abcd", db_row.get::<_, &str>("string"));

        // Verify - date
        assert_eq!(
            NaiveDate::from_ymd_opt(2024, 3, 1).unwrap(),
            db_row.get::<_, NaiveDate>("date")
        );

        // Verify - number
        assert_eq!(123, db_row.get::<_, i32>("number"));

        // Verify - small_number
        assert_eq!(16, db_row.get::<_, i16>("small_number"));

        // Verify - big_number
        assert_eq!(231, db_row.get::<_, i64>("big_number"));

        // Verify - float
        assert_eq!(231.23, db_row.get::<_, f64>("float"));

        // Verify - active
        assert!(db_row.get::<_, bool>("bool"));
    }
}
```


### db table 
```sql
CREATE TABLE IF NOT EXISTS test_db (
    id BIGSERIAL PRIMARY KEY NOT NULL,
    created_on TIMESTAMP DEFAULT now(),
    modified_on TIMESTAMP DEFAULT now(),
    string VARCHAR(64),
    date Date,
    number INT,
    small_number SMALLINT,
    big_number BIGINT,
    float DOUBLE PRECISION,
    is_active BOOLEAN
);
```
