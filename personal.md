```rust
// Api - Blog-post

use serde::{Deserialize, Serialize};
use tokio_postgres::types::ToSql;
use tokio_postgres::Row;
use validator::{Validate, ValidateArgs};

use crate::{blog_tag, validation, GRID_ROWS_PER_PAGE};
use crate::{ApiError, DBConnection};

// Constants
static STATUS_DRAFT: &str = "D";
static NO_VISITS_ZERO: i64 = 0;
static STATUS_LIST: [&str; 4] = ["D", "P", "A", "all"];
static SORT_BY_LIST: [&str; 3] = ["id", "date", "visits"];

#[derive(Debug, Serialize)]
pub struct BlogPost {
    title: String,
    content: String,

    #[serde(rename(serialize = "createBy"))]
    create_by: String,
    slug: String,

    #[serde(rename(serialize = "seoTitle"))]
    seo_title: String,

    #[serde(rename(serialize = "seoKeywords"))]
    seo_keywords: Vec<String>,

    #[serde(rename(serialize = "seoDescription"))]
    seo_description: String,

    #[serde(rename(serialize = "publishedOn"))]
    published_on: chrono::NaiveDateTime,

    tags: Vec<String>,
}

impl BlogPost {
    fn new(row: &Row) -> BlogPost {
        // Tags
        let db_tags: String = row.get("tags");
        let str_tags: Vec<&str> = db_tags.split('#').collect();
        let mut tags: Vec<String> = str_tags.iter().map(|&ele| ele.to_string()).collect();
        tags.remove(0);
        tags.remove(tags.len() - 1);

        // SEO Keyword
        let db_keyword: String = row.get("seo_keywords");
        let str_keyword: Vec<&str> = db_keyword.split('#').collect();
        let mut seo_keywords: Vec<String> = str_tags.iter().map(|&ele| ele.to_string()).collect();
        tags.remove(0);
        tags.remove(tags.len() - 1);

        BlogPost {
            title: row.get("title"),
            content: row.get("content"),
            create_by: row.get("create_by"),
            slug: row.get("slug"),
            seo_title: row.get("seo_title"),
            seo_keywords,
            seo_description: row.get("seo_description"),
            published_on: row.get("published_on"),
            tags,
        }
    }
}

#[derive(Debug, Validate, Deserialize)]
pub struct BlogPostSearchInput {
    keyword: Option<String>,

    #[validate(custom(function = "validation::list", arg = "&'v_a Vec<&'v_a str>"))]
    #[serde(default = "p")]
    status: Option<String>,

    #[validate(custom(function = "validation::list", arg = "&'v_a Vec<&'v_a str>"))]
    #[serde(rename(deserialize = "sortBy"))]
    sort_by: Option<String>,

    #[validate(range(min = 1))]
    #[serde(rename(deserialize = "pageNo"))]
    page_no: i64,
}

fn p() -> Option<String> {
    Some("P".to_string())
}

// Search
pub async fn search(
    db: &DBConnection<'_>,
    input: &BlogPostSearchInput,
) -> Result<(Vec<BlogPost>, i64, i64), ApiError> {
    if input
        .validate_args((&STATUS_LIST.to_vec(), &SORT_BY_LIST.to_vec()))
        .is_err()
    {
        return Err(ApiError::Error("Invalid data".to_string()));
    }

    let mut query = "FROM blog_post ".to_string();
    let mut params: Vec<&(dyn ToSql + Sync)> = Vec::new();
    let mut where_class: Vec<String> = vec![];

    // Check wether the keyword exit in the title or tag
    let int_key: String;
    if let Some(key) = &input.keyword {
        where_class.push(format!(
            " (tags LIKE ${} seo_keywords LIKE ${} OR OR title ~* ${} OR seo_title ~* ${} OR seo_description~* ${})",
            params.len() + 1,
            params.len() + 1,
            params.len() + 2,
            params.len() + 2,
            params.len() + 2
        ));
        int_key = format!("%#{}#%", key.to_lowercase());
        params.push(&int_key);
        params.push(&input.keyword);
    }

    if let Some(status) = input.status.clone() {
        if status != "all" {
            query += format!(" AND status = ${}", params.len() + 1).as_str();
            params.push(&input.status);
        }
    }

    if !where_class.is_empty() {
        query += " WHERE ";
        query += where_class.join(" AND ").as_str();
    }

    // Get the count and calculate pages
    let mut count: i64 = 0;
    let mut new_page_no: i64 = input.page_no;
    if let Ok(row) = db
        .query_one(&format!("SELECT COUNT(id) as count {}", query), &params)
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

    if new_page_no > total_pages {
        new_page_no = total_pages;
    }

    if let Some(sort_by) = input.sort_by.clone() {
        if sort_by == "date" {
            query += " ORDER BY published_on DESC";
        } else if sort_by == "visits" {
            query += " ORDER BY visits DESC";
        }
    }

    query = format!(
        "SELECT * {} LIMIT {} OFFSET {}",
        query,
        GRID_ROWS_PER_PAGE,
        (new_page_no - 1) * GRID_ROWS_PER_PAGE
    );

    // Get the rows based on pagination
    let rows = db.query(&query, &params).await?;
    let items: Vec<BlogPost> = rows.iter().map(BlogPost::new).collect();

    Ok((items, new_page_no, total_pages))
}

// Get by id

pub async fn get_by_id(db: &DBConnection<'_>, id: &i64) -> Result<Option<BlogPost>, ApiError> {
    let row = db
        .query("SELECT * FROM blog_post WHERE id = $1", &[&id])
        .await?;
    if row.is_empty() {
        return Err(ApiError::Error(format!("Tag \"{}\" does not exist", id)));
    }

    db.query(
        "UPDATE blog_post SET no_visits = no_visits + 1 WHERE id = $1",
        &[id],
    )
    .await?;

    let row = db
        .query_one("SELECT * FROM blog_post WHERE id = $1", &[&id])
        .await?;

    Ok(Some(BlogPost::new(&row)))
}

// Create

#[derive(Debug, Deserialize, Validate, Clone)]
pub struct BlogPostCreateInput {
    title: String,
    content: String,

    #[validate(custom = "validation::word")]
    slug: String,

    #[serde(rename(deserialize = "seoTitle"))]
    seo_title: String,

    #[validate(custom = "validation::tags")]
    #[serde(rename(deserialize = "seoKeywords"))]
    seo_keywords: Vec<String>,

    #[serde(rename(deserialize = "seoDescription"))]
    seo_description: String,

    #[serde(rename(deserialize = "publishedOn"))]
    published_on: chrono::NaiveDateTime,

    #[validate(custom = "validation::tags")]
    tags: Vec<String>,
}

pub async fn create(
    db: &DBConnection<'_>,
    username: &String,
    input: &BlogPostCreateInput,
) -> Result<i64, ApiError> {
    if input.validate().is_err() {
        return Err(ApiError::Error("Invalid data".to_string()));
    }

    for ele in &input.tags {
        let count = db
            .query("SELECT id FROM blog_tag WHERE name = $1", &[&ele])
            .await?;

        // Check tag already exist
        if count.is_empty() {
            let tag_id = blog_tag::create(db, ele).await?;
            db.query(
                "UPDATE blog_tag SET no_posts = no_posts + 1 WHERE id = $1",
                &[&tag_id],
            )
            .await?;
        } else if let Some(tag_id) = count.first() {
            db.query(
                "UPDATE blog_tag SET no_posts = no_posts + 1 WHERE id = $1",
                &[&tag_id.get::<_, i64>("id")],
            )
            .await?;
        }
    }

    // Insert into blog post table
    let tags_string = format!("#{}#", input.tags.join("#").to_lowercase());
    let seo_keyword_string = format!("#{}#", input.seo_keywords.join("#").to_lowercase());
    let query = "INSERT INTO blog_post (title, content, create_by, slug, status, 
        seo_title, seo_keywords, seo_description, published_on, tags, no_visits) VALUES
        ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11) RETURNING id"
        .to_string();

    let params: Vec<&(dyn ToSql + Sync)> = vec![
        &input.title,
        &input.content,
        &username,
        &input.slug,
        &STATUS_DRAFT,
        &input.seo_title,
        &seo_keyword_string,
        &input.seo_description,
        &input.published_on,
        &tags_string,
        &NO_VISITS_ZERO,
    ];

    let rows = db.query(&query, &params).await?;
    let Some(row) = rows.first() else {
        return Err(ApiError::Error("Unable to create new post".to_string()));
    };

    Ok(row.get(0))
}

// Update by id

#[derive(Debug, Deserialize, Validate)]
pub struct BlogPostUpdateInput {
    title: Option<String>,
    content: Option<String>,

    #[validate(custom = "validation::word")]
    slug: Option<String>,

    #[validate(custom(function = "validation::list", arg = "&'v_a Vec<&'v_a str>"))]
    status: Option<String>,

    #[serde(rename(deserialize = "seoTitle"))]
    seo_title: Option<String>,

    #[validate(custom = "validation::tags")]
    #[serde(rename(deserialize = "seoKeywords"))]
    seo_keywords: Option<Vec<String>>,

    #[serde(rename(deserialize = "seoDescription"))]
    seo_description: Option<String>,

    #[serde(rename(deserialize = "publishedOn"))]
    published_on: chrono::NaiveDateTime,

    #[validate(custom = "validation::tags")]
    tags: Option<Vec<String>>,
}

pub fn update_by_id(
    db: &DBConnection<'_>,
    id: &i64,
    input: &BlogPostUpdateInput,
) -> Result<bool, ApiError> {
    if input.validate_args(&STATUS_LIST.to_vec()).is_err() {
        return Err(ApiError::Error("Invalid data".to_string()));
    }

    Ok(true)
}

// Delete by id

pub async fn delete_by_id() {}
```
