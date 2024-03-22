```rust
pub async fn get_list(
    db: &DBConnection<'_>,
    project_id: i64,
    with_archive: bool,
    input: &RequirementGetListOptions,
) -> Result<Vec<Requirement>, ApiError> {
    let mut params: Vec<&(dyn ToSql + Sync)> = Vec::new();
    let mut query = " FROM requirement".to_string();
    let mut where_clauses: Vec<String> = vec![];

    // Check for keyword
    let int_tag: String;
    if let Some(tag) = &input.tags {
        if !tag.is_empty() {
            where_clauses.push(format!("tags LIKE ${}", params.len() + 1));
            int_tag = format!("%#{}#%", tag);
            params.push(&int_tag);
        }
    }

    if !input.show_all {
        where_clauses.push("status != 'C' AND status != 'A'".to_string());
    } else if !with_archive && input.show_all {
        where_clauses.push("status != 'A'".to_string());
    }

    where_clauses.push(format!("project_id = ${}", params.len() + 1));
    params.push(&project_id);

    query = "SELECT * ".to_owned() + &query + " WHERE " + where_clauses.join(" AND ").as_str();
    let rows = db.query(&query, &params).await?;

    let items: Vec<Requirement> = rows
        .iter()
        .map(|row| {
            let mut tags: Vec<String> = vec![];
            if let Some(tag) = row.get::<_, Option<&str>>("tags") {
                tags = string_to_vector(tag);
            }
            Requirement {
                id: row.get("id"),
                requirement: row.get("requirement"),
                description: row.get("description_html"),
                status: row.get("status"),
                display_status: common::get_display_status(row.get("status")),
                progress: row.get("progress"),
                tags,
            }
        })
        .collect();

    Ok(items)
}

pub struct Requirement {
    pub id: i64,
    pub requirement: String,
    pub description: String,
    pub status: String,
    pub display_status: String,
    pub progress: i16,
    pub tags: Vec<String>,
}

<span>
    <% for tag in item.tags.iter() { %>
        <%= tag %>
    <% } %>
</span>
```
