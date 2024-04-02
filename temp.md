```rust
use chrono::NaiveDateTime;

use crate::{ApiError, DBConnection};

pub struct PostDetail{
    id: i64,
    title: String,
    content: String,
    summary: String,
    image: String,
    created_by: String,
    slug: String,
    seo_title: String,
    seo_keywords: String,
    seo_description: String,
    published_on: NaiveDateTime,
    no_visits: i16,
    weightage: i16
}


pub async fn get_by_slug(
    db: &DBConnection<'_>,
    slug: &String,
) -> Result<Option<PostDetail>, ApiError> {
    let Some(row) = db
        .query_opt("SELECT * FROM blog_post WHERE slug LIKE $1", &[&slug])
        .await?
    else {
        return Err(ApiError::Error(format!("Slug {} is not available", slug)));
    };

    Ok(Some(PostDetail {
        id: row.get("id"),
        title: row.get("title"),
        content: row.get("content"),
        summary: row.get("summary"),
        image: row.get("image"),
        created_by: row.get("created_by"),
        slug: row.get("slug"),
        published_on: row.get("published_on"),
        seo_title: row.get("Seo_title"),
        seo_keywords: row.get("seo_keywords"),
        no_visits: row.get("no_visits"),
        seo_description: row.get("seo_description"),
        weightage: row.get("weightage")
    }))
}



pub struct TagItem {
    id: i64,
    name: String,
    no_post: i16
}

pub async fn get_list(db: &DBConnection<'_>,) -> Result<Vec<TagItem>, ApiError> {
    let rows = db.query("SELECT * FROM blog_tags", &[]).await?;

    let tags: Vec<TagItem> = rows.iter().map(|row| TagItem{
        id: row.get("id"),
        name: row.get("name"),
        no_post: row.get("no_post"),
    }).collect();

    Ok(tags)
}

```
