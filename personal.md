
```rust
// Api - Privilege

use std::collections::HashMap;

use super::ApiError;
use tokio_postgres::types::ToSql;
use validator::Validate;

use crate::{
    api::{validation, GRID_ROWS_PER_PAGE},
    db::DBConnection,
};

/* Structs */

#[derive(Debug, Validate, Clone)]
pub struct GetListOptions {
    #[validate(custom = "validation::keyword")]
    pub keyword: Option<String>,
    pub show_archive: Option<bool>,
    pub sort_by: Option<String>,
    pub sort_asc: Option<bool>,

    #[validate(range(min = 1))]
    pub page_no: i64,
}

#[derive(Debug, Clone)]
pub struct Privilege {
    id: i64,
    title: String,
    module: String,
    object: String,
    action: String,
}

/* Private Functions */

/* Public Functions */

pub async fn get_list(
    db: &DBConnection<'_>,
    options: GetListOptions,
) -> Result<(Vec<Privilege>, i64, i64), ApiError> {
    // Validate the input
    if options.validate().is_err() {
        return Err(ApiError::Error("Invalid data".to_string()));
    }

    let mut query = " FROM privilege".to_string();
    let mut params: Vec<&(dyn ToSql + Sync)> = Vec::new();
    let mut where_class: Vec<String> = vec![];

    if options.keyword.is_some() {
        where_class.push(format!("title ~* ${}", params.len() + 1));
        params.push(&options.keyword);
    }

    if !where_class.is_empty() {
        query += " WHERE ";
        query += where_class.join(" AND ").as_str();
    }

    // Get the count and calculate pages
    let mut count: i64 = 0;
    let mut page_no: i64 = options.page_no;
    if let Ok(row) = db
        .query_one(&format!("SELECT COUNT(id) AS count {}", query), &params)
        .await
    {
        count = row.get(0)
    }

    // If no records found, return empty result
    if count == 0 {
        return Ok((Vec::new(), 0, 1));
    }

    let mut total_pages: i64 = count / GRID_ROWS_PER_PAGE;
    if count % GRID_ROWS_PER_PAGE > 0 {
        total_pages += 1;
    }

    if page_no > total_pages {
        page_no = total_pages;
    }

    if let (Some(sort_by), Some(sort_asc)) = (&options.sort_by, &options.sort_asc) {
        let sort_map = HashMap::from([("role", "title"), ("created on", "created_on")]);

        if let Some(key) = sort_map.get(sort_by.as_str()) {
            let sort_order = if *sort_asc { "ASC" } else { "DESC" };
            query += &format!(" ORDER BY {} {}", key, sort_order);
        }
    }

    query = format!(
        "SELECT id, title, module, object, action {} LIMIT {} OFFSET {}",
        query,
        GRID_ROWS_PER_PAGE,
        (page_no - 1) * GRID_ROWS_PER_PAGE
    );

    println!("{}", query);
    let rows = db.query(&query, &params).await?;

    let items: Vec<Privilege> = rows
        .iter()
        .map(|row| Privilege {
            id: row.get("id"),
            title: row.get("title"),
            module: row.get("module"),
            object: row.get("object"),
            action: row.get("action"),
        })
        .collect();

    Ok((items, page_no, total_pages))
}

```
