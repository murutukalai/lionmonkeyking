```rust
// Api - Blog-post

use serde::{Deserialize, Serialize};
use tokio_postgres::types::ToSql;
use validator::Validate;

use crate::{string_to_vector, validation};
use crate::{ApiError, DBConnection};

// Constants
const STATUS_PUBLISHED: &str = "P";
const STATUS_NEW: &str = "new";

#[derive(Debug, Clone, Deserialize)]
enum Sort {
    Recent,
    Popular,
}

#[derive(Debug, Serialize)]
pub struct Post {
    id: i64,
    title: String,
    summary: String,
    image: Vec<String>,

    #[serde(rename(serialize = "createdBy"))]
    created_by: String,

    slug: String,

    #[serde(rename(serialize = "publishedOn"))]
    published_on: Option<chrono::NaiveDateTime>,

    tags: Vec<String>,
}

#[derive(Debug, Validate, Deserialize, Clone)]
pub struct BlogPostSearchInput {
    #[serde(rename(deserialize = "type"))]
    sort_type: Sort,

    #[validate(custom = "validation::word")]
    keyword: Option<String>,

    #[validate(range(min = 1))]
    #[serde(rename(deserialize = "maxRows"))]
    max_rows: i64,

    #[validate(range(min = 1))]
    #[serde(rename(deserialize = "pageNo"))]
    page_no: i64,
}

fn form_tags(all_tags: &[String], db_tags: &str) -> Vec<String> {
    let db_tag_vec = string_to_vector(db_tags);
    let sorted_tags: Vec<String> = all_tags
        .iter()
        .filter(|&itm| db_tag_vec.contains(itm))
        .cloned()
        .collect();
    sorted_tags
}

// Search
pub async fn get_list(
    db: &DBConnection<'_>,
    input: &BlogPostSearchInput,
) -> Result<(Vec<Post>, i64, i64), ApiError> {
    if input.validate().is_err() {
        return Err(ApiError::Error("Invalid data".to_string()));
    }

    let mut query = "FROM blog_post".to_string();
    let mut params: Vec<&(dyn ToSql + Sync)> = Vec::new();
    let mut where_class: Vec<String> = vec![];

    // Check wether the keyword exit in the title or tag
    let int_key: String;
    if let Some(key) = &input.keyword {
        where_class.push(format!(
            "(tags LIKE ${} OR title ~* ${} OR content ~* ${})",
            params.len() + 1,
            params.len() + 2,
            params.len() + 2
        ));
        int_key = format!("%#{}#%", key.to_lowercase());
        params.push(&int_key);
        params.push(&input.keyword);
    }

    where_class.push(format!("status = ${}", params.len() + 1));
    params.push(&STATUS_PUBLISHED);

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

    let mut total_pages: i64 = count / input.max_rows;
    if count % input.max_rows > 0 {
        total_pages += 1;
    }

    if new_page_no > total_pages {
        new_page_no = total_pages;
    }

    match input.sort_type {
        Sort::Popular => query += " ORDER BY no_visits DESC",
        Sort::Recent => query += " ORDER BY published_on DESC",
    }

    query = format!(
        "SELECT * {} LIMIT {} OFFSET {}",
        query,
        input.max_rows,
        (new_page_no - 1) * input.max_rows
    );

    // Get the rows based on pagination
    let rows = db.query(&query, &params).await?;
    let mut items: Vec<Post> = Vec::new();

    // Sorted tags
    let tags_rows = db
        .query("SELECT * FROM blog_tag ORDER BY no_posts DESC", &[])
        .await?;
    let all_tags: Vec<String> = tags_rows.iter().map(|row| row.get("name")).collect();

    for row in rows {
        // Get images from db
        let img_vec: Vec<String>;
        if let Some(image) = row.get("image") {
            img_vec = string_to_vector(image);
        } else {
            img_vec = vec![]
        };

        items.push(Post {
            id: row.get("id"),
            title: row.get("title"),
            summary: row.get("summary"),
            image: img_vec,
            created_by: row.get("created_by"),
            slug: row.get("slug"),
            published_on: row.get("published_on"),
            tags: form_tags(&all_tags, row.get::<_, &str>("tags")),
        });
    }

    Ok((items, total_pages, new_page_no))
}

// Get by slug
#[derive(Debug, Serialize, Clone)]
pub struct PostDetail {
    id: i64,
    title: String,
    content: String,
    summary: String,
    image: Vec<String>,

    #[serde(rename(serialize = "createBy"))]
    created_by: String,

    #[serde(rename(serialize = "publishedOn"))]
    published_on: chrono::NaiveDateTime,

    tags: Vec<String>,
}

pub async fn get_by_slug(
    db: &DBConnection<'_>,
    slug: &String,
) -> Result<Option<PostDetail>, ApiError> {
    let Some(row) = db
        .query_opt("SELECT * FROM blog_post WHERE slug LIKE $1", &[&slug])
        .await?
    else {
        return Err(ApiError::Error("Slug is not available".to_string()));
    };

    // Get images from db
    let img_vec: Vec<String>;
    if let Some(image) = row.get("image") {
        img_vec = string_to_vector(image);
    } else {
        img_vec = vec![]
    };

    // Converting # separated to vector
    let string_params = string_to_vector(row.get::<_, String>("tags").as_str());

    // Converting Vec<String> to Vec<&(dyn ToSql + Sync)>
    let params: Vec<&(dyn ToSql + Sync)> = string_params
        .iter()
        .map(|itm| itm as &(dyn ToSql + Sync))
        .collect();
    let value: Vec<String> = params
        .iter()
        .enumerate()
        .map(|(itm, _)| format!("${}", itm + 1))
        .collect();

    // Get tags sorted by post
    let query = format!(
        "SELECT name FROM blog_tag WHERE name IN ({}) ORDER BY no_posts DESC",
        value.join(", ")
    );
    let rows = db.query(&query, &params).await?;
    let tag_list: Vec<String> = rows.iter().map(|row| row.get("name")).collect();

    Ok(Some(PostDetail {
        id: row.get("id"),
        title: row.get("title"),
        content: row.get("content"),
        summary: row.get("summary"),
        image: img_vec,
        created_by: row.get("created_by"),
        published_on: row.get("published_on"),
        tags: tag_list,
    }))
}

// Contact
#[derive(Debug, Deserialize, Validate, Clone)]
pub struct ContactInput {
    #[validate(email)]
    email: String,

    #[validate(custom = "validation::word")]
    name: String,
    message: String,

    #[validate(custom = "validation::number")]
    #[serde(rename(deserialize = "phoneNo"))]
    phone_no: Option<String>,
}
pub async fn contact(
    db: &DBConnection<'_>,
    ip_address: &String,
    input: &ContactInput,
) -> Result<bool, ApiError> {
    if input.validate().is_err() {
        return Err(ApiError::Error("Invalid data".to_string()));
    }
    let count = db
        .query(
            "SELECT id FROM contact WHERE ip_address = $1 AND status = $2",
            &[&ip_address, &STATUS_NEW],
        )
        .await?;

    if !count.is_empty() {
        return Err(ApiError::Error("Invalid request".to_string()));
    }

    let query = "INSERT INTO contact (email, ip_address, name, message, phone_no, status)
        VALUES ($1, $2, $3, $4, $5, $6)"
        .to_string();

    let params: Vec<&(dyn ToSql + Sync)> = vec![
        &input.email,
        &ip_address,
        &input.name,
        &input.message,
        &input.phone_no,
        &STATUS_NEW,
    ];

    let val = db.execute(&query, &params).await?;

    Ok(val != 0)
}

pub async fn subscription(
    db: &DBConnection<'_>,
    ip_address: &String,
    email: &String,
) -> Result<bool, ApiError> {
    // Validate - email
    if !email.contains('@') && !email.contains('.') {
        return Err(ApiError::Error("Invalid data".to_string()));
    }

    let count = db
        .query(
            "SELECT id FROM subscription WHERE ip_address = $1 OR email = $2",
            &[&ip_address, &email],
        )
        .await?;

    if !count.is_empty() {
        return Err(ApiError::Error("Email already exist".to_string()));
    }

    let query = "INSERT INTO subscription (email, ip_address, status)
        VALUES ($1, $2, $3)"
        .to_string();

    let params: Vec<&(dyn ToSql + Sync)> = vec![&email, &ip_address, &STATUS_NEW];

    let val = db.execute(&query, &params).await?;

    Ok(val != 0)
}

#[cfg(test)]
mod test {
    use super::*;
    use crate::initialize_db;

    #[tokio::test]
    async fn test_get_list() {
        let pool = initialize_db().await.unwrap();
        let db = pool.get().await.unwrap();

        // Creating a Basic input for all test case
        let input = BlogPostSearchInput {
            sort_type: Sort::Popular,
            keyword: None,
            max_rows: 2,
            page_no: 1,
        };

        // Verify - invalid keyword
        let val = get_list(
            &db,
            &BlogPostSearchInput {
                keyword: Some("SQL@".to_string()),
                ..input.clone()
            },
        )
        .await;

        assert!(matches!(val, Err(ApiError::Error(err)) if err == "Invalid data"));

        // Verify - invalid page no
        let val = get_list(
            &db,
            &BlogPostSearchInput {
                page_no: 0,
                ..input.clone()
            },
        )
        .await;

        assert!(matches!(val, Err(ApiError::Error(err)) if err == "Invalid data"));

        // Verify - invalid max row
        let val = get_list(
            &db,
            &BlogPostSearchInput {
                max_rows: 0,
                ..input.clone()
            },
        )
        .await;

        assert!(matches!(val, Err(ApiError::Error(err)) if err == "Invalid data"));

        // Verify - without keyword
        let (ret_val, total_pages, page_no) = get_list(&db, &input).await.unwrap();

        assert_eq!(ret_val.len(), 2);
        assert_eq!(page_no, 1);
        assert_eq!(total_pages, 5);

        // Verify - with keyword
        let (ret_val, total_pages, page_no) = get_list(
            &db,
            &BlogPostSearchInput {
                keyword: Some("visualization".to_string()),
                ..input.clone()
            },
        )
        .await
        .unwrap();
        assert_eq!(ret_val.len(), 1);
        assert_eq!(page_no, 1);
        assert_eq!(total_pages, 1);

        // Verify - with sort by popular
        let (ret_val, total_pages, page_no) = get_list(&db, &input.clone()).await.unwrap();

        assert_eq!(ret_val.len(), 2);
        assert_eq!(page_no, 1);
        assert_eq!(total_pages, 5);
        assert_eq!(ret_val[0].slug, "mobile-app-development-tips".to_string());

        // Verify - with sort recent post
        let (ret_val, total_pages, page_no) = get_list(
            &db,
            &BlogPostSearchInput {
                sort_type: Sort::Recent,
                ..input.clone()
            },
        )
        .await
        .unwrap();

        assert_eq!(ret_val.len(), 2);
        assert_eq!(page_no, 1);
        assert_eq!(total_pages, 5);
        assert_eq!(ret_val[0].slug, "data-visualization-techniques".to_string());

        // Verify - with max rows - 5
        let (ret_val, total_pages, page_no) = get_list(
            &db,
            &BlogPostSearchInput {
                max_rows: 5,
                ..input.clone()
            },
        )
        .await
        .unwrap();

        assert_eq!(ret_val.len(), 5);
        assert_eq!(page_no, 1);
        assert_eq!(total_pages, 2);

        // Verify - with max rows - 10
        let (ret_val, total_pages, page_no) = get_list(
            &db,
            &BlogPostSearchInput {
                max_rows: 10,
                ..input.clone()
            },
        )
        .await
        .unwrap();

        assert_eq!(ret_val.len(), 10);
        assert_eq!(page_no, 1);
        assert_eq!(total_pages, 1);

        // Verify - with different page
        let (ret_val, total_pages, page_no) = get_list(
            &db,
            &BlogPostSearchInput {
                page_no: 2,
                ..input.clone()
            },
        )
        .await
        .unwrap();

        assert_eq!(ret_val.len(), 2);
        assert_eq!(page_no, 2);
        assert_eq!(total_pages, 5);

        // Verify - with unavailable page
        let (ret_val, total_pages, page_no) = get_list(
            &db,
            &BlogPostSearchInput {
                page_no: 20,
                ..input.clone()
            },
        )
        .await
        .unwrap();

        assert_eq!(ret_val.len(), 2);
        assert_eq!(page_no, 5);
        assert_eq!(total_pages, 5);

        // Verify - get by tag
        let (ret_val, total_pages, page_no) = get_list(
            &db,
            &BlogPostSearchInput {
                keyword: Some("test".to_string()),
                max_rows: 10,
                ..input.clone()
            },
        )
        .await
        .unwrap();

        assert_eq!(ret_val.len(), 4);
        assert_eq!(page_no, 1);
        assert_eq!(total_pages, 1);

        // Verify - tags sort by no_post descending order
        let (ret_val, total_pages, page_no) = get_list(
            &db,
            &BlogPostSearchInput {
                keyword: Some("frontend-frameworks".to_string()),
                max_rows: 10,
                ..input.clone()
            },
        )
        .await
        .unwrap();

        assert_eq!(ret_val.len(), 1);
        assert_eq!(page_no, 1);
        assert_eq!(total_pages, 1);

        let tag_vec = &ret_val[0].tags;
        assert_eq!(tag_vec[0], "cloud-computing");
        assert_eq!(tag_vec[1], "artificial-intelligence");
    }

    #[tokio::test]
    async fn test_get_by_slug() {
        let pool = initialize_db().await.unwrap();
        let db = pool.get().await.unwrap();

        // Verify - with valid slug
        let val = get_by_slug(&db, &"frontend-frameworks-comparison".to_string())
            .await
            .unwrap();

        assert!(val.is_some());
        let val = val.unwrap();
        assert_eq!(val.created_by, "Pavithara");

        // Verify - with invalid slug
        let val = get_by_slug(&db, &"validate".to_string()).await;

        assert!(val.is_err());
        assert!(matches!(val, Err(ApiError::Error(err)) if err == "Slug is not available"));
    }

    #[tokio::test]
    async fn test_contact() {
        let pool = initialize_db().await.unwrap();
        let db = pool.get().await.unwrap();

        // Basic struct input for contact
        let input = ContactInput {
            email: "jayasuriya@crypton.tech".to_string(),
            name: "Jayasuriya".to_string(),
            message: "Can get more details".to_string(),
            phone_no: Some("0909876432".to_string()),
        };

        // Verify - invalid email
        let val = contact(
            &db,
            &"127.0.0.1".to_string(),
            &ContactInput {
                email: "email".to_string(),
                ..input.clone()
            },
        )
        .await;
        assert!(matches!(val, Err(ApiError::Error(err)) if err == "Invalid data"));

        // Verify - invalid name
        let val = contact(
            &db,
            &"127.0.0.1".to_string(),
            &ContactInput {
                name: "@".to_string(),
                ..input.clone()
            },
        )
        .await;
        assert!(matches!(val, Err(ApiError::Error(err)) if err == "Invalid data"));

        let val = contact(&db, &"127.0.0.10".to_string(), &input)
            .await
            .unwrap();

        // assert!(val);

        let db_row = db
            .query_one("SELECT * FROM contact WHERE ip_address = '127.0.0.10'", &[])
            .await;
        let db_row = db_row.unwrap();

        // Verify - email
        assert_eq!(
            "jayasuriya@crypton.tech".to_string(),
            db_row.get::<_, String>("email")
        );

        // Verify - name
        assert_eq!("Jayasuriya".to_string(), db_row.get::<_, String>("name"));

        // Verify - message
        assert_eq!(
            "Can get more details".to_string(),
            db_row.get::<_, String>("message")
        );

        // Verify - with already created ip with new status
        let val = contact(&db, &"127.0.0.10".to_string(), &input).await;

        assert!(matches!(val, Err(ApiError::Error(err)) if err == "Invalid request"));
    }

    #[tokio::test]
    async fn test_subscription() {
        let pool = initialize_db().await.unwrap();
        let db = pool.get().await.unwrap();

        // Verify - with valid input
        let val = subscription(
            &db,
            &"127.0.0.1".to_string(),
            &"jayasuriya@crypton.tech".to_string(),
        )
        .await
        .unwrap();
        assert!(val);

        // Verify - with invalid email
        let val = subscription(&db, &"127.0.0.1".to_string(), &"jayasuriya".to_string())
            .await;
        assert!(matches!(val, Err(ApiError::Error(err)) if err == "Invalid data"));

        // Verify - with already exist email 
        let val = subscription(&db, &"127.0.0.1".to_string(), &"jayasuriya@crypton.tech".to_string())
            .await;
        assert!(matches!(val, Err(ApiError::Error(err)) if err == "Email already exist"));
    }
}

```
