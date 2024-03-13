## privilege api
```rust

#[cfg(test)]
mod tests {
    use crate::initialize_db;
    use super::*;

    #[tokio::test]
    async fn test_get_by_id() {
        let pool = initialize_db().await.unwrap();
        let db = pool.get().await.unwrap();

        // Invalid id
        let val = get_by_id(&db, 2000).await;
        assert!(
            matches!(val, Err(ApiError::Error(err)) if err == "Privilege with id '2000' does not exist")
        );

        // Verify valid id
        let val = get_by_id(&db, 1).await.unwrap().unwrap();
        assert_eq!(val.title, "Add role".to_string());
        assert_eq!(val.module, "security".to_string());
        assert_eq!(val.object, "role".to_string());
        assert_eq!(val.action, "add".to_string());
    }

    #[tokio::test]
    async fn test_create() {
        let pool = initialize_db().await.unwrap();
        let db = pool.get().await.unwrap();

        let val = create(
            &db,
            &PrivilegeCreateInput {
                title: "Create news".to_string(),
                module: "News".to_string(),
                object: "Post".to_string(),
                action: "create".to_string(),
            },
        )
        .await
        .unwrap();

        let db_row = db
            .query_one("SELECT * FROM privilege WHERE id = $1", &[&val])
            .await
            .unwrap();

        // Verify - title
        assert_eq!("Create news".to_string(), db_row.get::<_, String>("title"));

        // Verify - module
        assert_eq!("News".to_string(), db_row.get::<_, String>("module"));

        // Verify - object
        assert_eq!("Post".to_string(), db_row.get::<_, String>("object"));

        // Verify - action
        assert_eq!("create".to_string(), db_row.get::<_, String>("action"));
    }

    #[tokio::test]
    async fn test_update() {
        let pool = initialize_db().await.unwrap();
        let db = pool.get().await.unwrap();

        let input = PrivilegeUpdateInput {
            title: None,
            module: None,
            object: None,
            action: None,
        };

        // Invalid id
        let val = update(&db, 2000, &input.clone()).await;
        assert!(
            matches!(val, Err(ApiError::Error(err)) if err == "Privilege with id '2000' does not exist")
        );

        // Verify without any date
        let val = update(&db, 3, &input.clone()).await;
        assert!(
            matches!(val, Err(ApiError::Error(err)) if err == "Enter minimum one data to update")
        );

        // Verify with title
        let val = update(
            &db,
            3,
            &PrivilegeUpdateInput {
                title: Some("Edit user management".to_string()),
                ..input.clone()
            },
        )
        .await;

        assert!(val.unwrap());
        let db_row = db
            .query_one("SELECT title FROM privilege WHERE id = 3", &[])
            .await
            .unwrap();

        // Verify - title
        assert_eq!(
            "Edit user management".to_string(),
            db_row.get::<_, String>("title")
        );

        // Verify with module
        let val = update(
            &db,
            3,
            &PrivilegeUpdateInput {
                module: Some("Management user".to_string()),
                ..input.clone()
            },
        )
        .await;

        assert!(val.unwrap());
        let db_row = db
            .query_one("SELECT module FROM privilege WHERE id = 3", &[])
            .await
            .unwrap();

        // Verify - module
        assert_eq!(
            "Management user".to_string(),
            db_row.get::<_, String>("module")
        );

        // Verify with object
        let val = update(
            &db,
            3,
            &PrivilegeUpdateInput {
                object: Some("Management".to_string()),
                ..input.clone()
            },
        )
        .await;

        assert!(val.unwrap());
        let db_row = db
            .query_one("SELECT object FROM privilege WHERE id = 3", &[])
            .await
            .unwrap();

        // Verify - object
        assert_eq!("Management".to_string(), db_row.get::<_, String>("object"));

        // Verify with action
        let val = update(
            &db,
            3,
            &PrivilegeUpdateInput {
                action: Some("Update".to_string()),
                ..input.clone()
            },
        )
        .await;

        assert!(val.unwrap());
        let db_row = db
            .query_one("SELECT action FROM privilege WHERE id = 3", &[])
            .await
            .unwrap();

        // Verify - action
        assert_eq!("Update".to_string(), db_row.get::<_, String>("action"));

        // Verify with all inputs
        let val = update(
            &db,
            3,
            &PrivilegeUpdateInput {
                title: Some("Delete Post".to_string()),
                module: Some("Blog".to_string()),
                object: Some("Post".to_string()),
                action: Some("Delete".to_string()),
            },
        )
        .await;

        assert!(val.unwrap());
        let db_row = db
            .query_one("SELECT * FROM privilege WHERE id = 3", &[])
            .await
            .unwrap();

        // Verify - title
        assert_eq!("Delete Post".to_string(), db_row.get::<_, String>("title"));

        // Verify - module
        assert_eq!("Blog".to_string(), db_row.get::<_, String>("module"));

        // Verify - object
        assert_eq!("Post".to_string(), db_row.get::<_, String>("object"));

        // Verify - action
        assert_eq!("Delete".to_string(), db_row.get::<_, String>("action"));
    }

    #[tokio::test]
    async fn test_delete_by_id() {
        let pool = initialize_db().await.unwrap();
        let db = pool.get().await.unwrap();

        // Invalid id
        let val = delete_by_id(&db, 2000).await;
        assert!(
            matches!(val, Err(ApiError::Error(err)) if err == "Privilege with id '2000' does not exist")
        );

        // Verify privilege is deleted in db
        let val = delete_by_id(&db, 4).await;
        assert!(val.unwrap());

        // Invalid id
        let val = get_by_id(&db, 4).await;
        assert!(
            matches!(val, Err(ApiError::Error(err)) if err == "Privilege with id '4' does not exist")
        );
    }
}
```

## Employee.stpl
```html
<% include!("../../includes/page_header.stpl"); %>

<h3>Employee <Details></Details></h3>
<%= employee.id %>
<%= employee.username %>
<%= employee.email %>
<%= employee.name %>
<%= employee.status %>
<%= employee.email %>
<%= employee.mobile %>
<%= employee.designation %>
<%= employee.gender %>
<%= employee.image %>
<%= employee.first_name %>
<%= employee.last_name %>
<%= employee.initial %>
<%= employee.degree %>
<%= employee.blood_group %>
<%= employee.marital_status %>
<%= employee.father_name %>
<%= employee.mother_name %>
<%= employee.city %>
<%= employee.current_address %>
<%= employee.permanent_address %>
<%= employee.education_details %>
<%= employee.experience_details %>
<%= employee.health_details %>
<%= employee.hobbies %>
<%= employee.is_active %>
<%= employee.joined_date %>
<%= employee.contact_other %>
<%= employee.contact_mother %>
<%= employee.contact_father %>
<%= employee.created_by %>
<%= employee.created_by_id %>
<% if let Some(exit_date) = employee.exit_date { %>
    <%= exit_date %>
<% } %>
<%= employee.description %>
<%= employee.is_trainee %>

<h3>Employee Roles</h3>
<% include!("../../includes/hrms/role_list.stpl"); %>

<h3>Employee Privileges</h3>
<% include!("../../includes/hrms/privilege_list.stpl"); %>

<% include!("../../includes/page_footer.stpl"); %>
```
## Employee api
```
// Libs - Backend-api - Hrms Module - Employee

use chrono::NaiveDateTime;
use serde::Deserialize;

use crate::{security::privilege::PrivilegeItem, ApiError, DBConnection};

#[derive(Debug, Clone, Deserialize)]
pub struct EmployeeDetail {
    pub id: i64,
    pub name: String,
    pub username: String,
    pub mobile: String,
    pub description: String,
    pub designation: String,
    pub email: String,
    pub gender: String,
    pub status: bool,
    pub image: String,
    pub first_name: String,
    pub last_name: String,
    pub initial: String,
    pub degree: String,
    pub blood_group: String,
    pub marital_status: String,
    pub father_name: String,
    pub mother_name: String,
    pub city: String,
    pub current_address: String,
    pub permanent_address: String,
    pub education_details: String,
    pub experience_details: String,
    pub health_details: String,
    pub hobbies: String,
    pub is_active: bool,
    pub is_trainee: bool,
    pub joined_date: String,
    pub contact_other: String,
    pub contact_mother: String,
    pub contact_father: String,
    pub created_by: String,
    pub created_by_id: i64,
    pub exit_date: Option<String>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct EmployeeInfo {
    pub id: i64,
    pub username: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct RoleItem {
    pub id: i64,
    pub title: String,
    pub description: String,
}

pub async fn get_by_username(
    db: &DBConnection<'_>,
    username: String,
) -> Result<EmployeeDetail, ApiError> {
    let rows = db
        .query_opt("SELECT * FROM employee WHERE username = $1", &[&username])
        .await?;
    let Some(row) = rows else {
        return Err(ApiError::Error(format!(
            "Employee with username '{}' does not exist",
            username
        )));
    };

    let exit_date = match row.try_get::<_, Option<NaiveDateTime>>("exit_date") {
        Ok(Some(date)) => Some(date.to_string()),
        _ => None,
    };

    Ok(EmployeeDetail {
        id: row.get("id"),
        name: row.get("name"),
        username: row.get("username"),
        status: row.get("is_active"),
        email: row.get("email"),
        mobile: row.get("mobile"),
        designation: row.get("designation"),
        gender: row.get("gender"),
        image: row.get("image"),
        first_name: row.get("first_name"),
        last_name: row.get("last_name"),
        initial: row.get("initial"),
        degree: row.get("degree"),
        blood_group: row.get("blood_group"),
        marital_status: row.get("marital_status"),
        father_name: row.get("father_name"),
        mother_name: row.get("mother_name"),
        city: row.get("city"),
        current_address: row.get("current_address"),
        permanent_address: row.get("permanent_address"),
        education_details: row.get("education_details"),
        experience_details: row.get("experience_details"),
        health_details: row.get("health_details"),
        hobbies: row.get("hobbies"),
        is_active: row.get("is_active"),
        joined_date: row.get::<_, NaiveDateTime>("joined_date").to_string(),
        contact_other: row.get("contact_other"),
        contact_mother: row.get("contact_mother"),
        contact_father: row.get("contact_father"),
        created_by: row.get("created_by"),
        created_by_id: row.get("created_by_id"),
        exit_date,
        description: row.get("description"),
        is_trainee: row.get("is_trainee"),
    })
}

pub async fn get_roles(db: &DBConnection<'_>, emp_id: i64) -> Result<Vec<RoleItem>, ApiError> {
    let rows = db
        .query(
            r#"SELECT r.id, r.title, r.description FROM employee_role AS er 
            INNER JOIN role AS r ON er.role_id = r.id 
            WHERE er.employee_id = $1"#,
            &[&emp_id],
        )
        .await?;

    let items: Vec<RoleItem> = rows
        .iter()
        .map(|row| RoleItem {
            id: row.get("id"),
            title: row.get("title"),
            description: row.get("description"),
        })
        .collect();

    Ok(items)
}

pub async fn get_privilege(
    db: &DBConnection<'_>,
    emp_id: i64,
) -> Result<Vec<PrivilegeItem>, ApiError> {
    let rows = db
        .query(
            r#"SELECT ep.employee_id, p.id, p.title, p.module, p.object, p.action 
            FROM employee_privilege ep 
            INNER JOIN privilege p ON ep.privilege_id = p.id
            WHERE ep.employee_id = $1"#,
            &[&emp_id],
        )
        .await?;

    let items: Vec<PrivilegeItem> = rows
        .iter()
        .map(|row| PrivilegeItem {
            id: row.get("id"),
            title: row.get("title"),
            module: row.get("module"),
            object: row.get("object"),
            action: row.get("action"),
        })
        .collect();
    Ok(items)
}

pub async fn role_add(db: &DBConnection<'_>, emp_id: i64, role_id: i64) -> Result<i64, ApiError> {
    let row = db
        .query_opt("SELECT * FROM role WHERE id = $1", &[&role_id])
        .await?;

    if row.is_none() {
        return Err(ApiError::Error(format!(
            "Role With id '{}' does not exist",
            role_id
        )));
    }

    let row = db
        .query_opt(
            "SELECT id FROM employee_role WHERE employee_id = $1 AND role_id = $2 ",
            &[&emp_id, &role_id],
        )
        .await?;

    if row.is_some() {
        return Err(ApiError::Error(format!(
            "Employee With id '{}' Already has role",
            emp_id
        )));
    }

    let employee_role_id = db
        .query_one(
            "INSERT INTO employee_role(role_id, employee_id) VALUES ($1, $2) RETURNING ID",
            &[&role_id, &emp_id],
        )
        .await?
        .get("id");

    Ok(employee_role_id)
}

pub async fn privilege_add(
    db: &DBConnection<'_>,
    emp_id: i64,
    privilege_id: i64,
    excluded_ids: &Option<String>,
) -> Result<i64, ApiError> {
    let privilege_exist = db
        .query_opt("SELECT id FROM privilege WHERE id = $1", &[&privilege_id])
        .await?;

    if privilege_exist.is_none() {
        return Err(ApiError::Error(format!(
            "Privilege With id '{}' does not exist",
            privilege_id
        )));
    }

    let exist = db
        .query_opt(
            "SELECT id FROM employee_privilege WHERE employee_id = $1 AND privilege_id = $2 ",
            &[&emp_id, &privilege_id],
        )
        .await?;

    if exist.is_some() {
        return Err(ApiError::Error(format!(
            "Employee With id '{}' Already has Privilege",
            emp_id
        )));
    }

    let employee_privilege_id = db
        .query_one(
            "INSERT INTO employee_privilege(employee_id,privilege_id excluded_ids)
            VALUES ($1, $2, $3) RETURNING ID",
            &[&emp_id, &privilege_id, &excluded_ids],
        )
        .await?
        .get("id");

    Ok(employee_privilege_id)
}

pub async fn delete_role(
    db: &DBConnection<'_>,
    emp_id: i64,
    role_id: i64,
) -> Result<bool, ApiError> {
    let count: i64 = db
        .query_one(
            "SELECT  COUNT(id) as count FROM employee_role WHERE employee_id = $1 AND role_id = $2",
            &[&emp_id, &role_id],
        )
        .await?
        .get("count");

    if count == 0 {
        return Err(ApiError::Error(format!(
            "Employee with role id '{}' does not exist",
            role_id
        )));
    }

    let val = db
        .execute(
            "DELETE FROM employee_role wHERE employee_id = $1 AND role_id = $2",
            &[&emp_id, &role_id],
        )
        .await?;

    Ok(val != 0)
}

pub async fn delete_privilege(
    db: &DBConnection<'_>,
    emp_id: i64,
    privilege_id: i64,
) -> Result<bool, ApiError> {
    let count: i64 = db
        .query_one(
            "SELECT COUNT(id) as count FROM employee_privilege 
            WHERE employee_id = $1 AND privilege_id = $2",
            &[&emp_id, &privilege_id],
        )
        .await?
        .get("count");

    if count == 0 {
        return Err(ApiError::Error(format!(
            "Employee with privilege id '{}' does not exist",
            emp_id
        )));
    }

    let val = db
        .execute(
            "DELETE FROM employee_privilege wHERE employee_id = $1 AND privilege_id = $2",
            &[&emp_id, &privilege_id],
        )
        .await?;

    Ok(val != 0)
}

#[cfg(test)]
mod test {
    use super::*;
    use crate::{initialize_db, ApiError};

    #[tokio::test]
    async fn test_get_by_username() {
        let pool = initialize_db().await.unwrap();
        let db = pool.get().await.unwrap();

        let val = get_by_username(&db, "admin".to_string()).await.unwrap();
        assert_eq!(val.id, 1);
        assert_eq!(val.username, "admin".to_string());

        // Verify Invalid username
        let val = get_by_username(&db, "jai".to_string()).await;
        assert!(
            matches!(val, Err(ApiError::Error(err)) if err == "Employee with username 'jai' does not exist")
        );
    }

    #[tokio::test]
    async fn test_get_by_id() {
        let pool = initialize_db().await.unwrap();
        let db = pool.get().await.unwrap();

        let val = get_by_username(&db, "admin".to_string()).await.unwrap();

        assert_eq!(val.id, 1);
        assert_eq!(val.name, "admin".to_string());
        assert_eq!(val.mobile, "1234567890".to_string());
        assert_eq!(val.designation, "Admin".to_string());
        assert_eq!(val.description, "better programming".to_string());
        assert_eq!(val.email, "admin@crypton.com".to_string());
        assert_eq!(val.gender, "M".to_string());
        assert!(!val.status);
        assert_eq!(val.image, "image".to_string());
        assert_eq!(val.first_name, "John".to_string());
        assert_eq!(val.last_name, "Doe".to_string());
        assert_eq!(val.initial, "Mr.       ".to_string());
        assert_eq!(val.degree, "MBA".to_string());
        assert_eq!(val.blood_group, "O+".to_string());
        assert_eq!(val.marital_status, "Single              ".to_string());
        assert_eq!(val.father_name, "David".to_string());
        assert_eq!(val.mother_name, "Mary".to_string());
        assert_eq!(val.city, "New York".to_string());
        assert_eq!(val.current_address, "123 Main St".to_string());
        assert_eq!(val.permanent_address, "456 Maple St".to_string());
        assert_eq!(val.education_details, "Bachelor in Business".to_string());
        assert_eq!(val.experience_details, "5 years".to_string());
        assert_eq!(val.health_details, "Good health condition".to_string());
        assert_eq!(val.hobbies, "Reading".to_string());
        assert!(!val.is_active);
        assert!(!val.is_trainee);
        assert_eq!(val.joined_date, "2024-02-29 00:00:00".to_string());
        assert_eq!(val.contact_other, "9876543210".to_string());
        assert_eq!(val.contact_mother, "9876543210".to_string());
        assert_eq!(val.contact_father, "9876543210".to_string());
        assert_eq!(val.created_by, "Admin".to_string());
        assert_eq!(val.created_by_id, 1);
        assert_eq!(val.exit_date, None);

        // Verify Invalid username
        let val = get_by_username(&db, "jai".to_string()).await;
        assert!(
            matches!(val, Err(ApiError::Error(err)) if err == "Employee with username 'jai' does not exist")
        );
    }

    #[tokio::test]
    async fn test_delete_role() {
        let pool = initialize_db().await.unwrap();
        let db = pool.get().await.unwrap();

        // Invalid id
        let val = delete_role(&db, 1, 20).await;
        assert!(
            matches!(val, Err(ApiError::Error(err)) if err == "Employee with role id '20' does not exist")
        );

        // Verify role is deleted in db
        let emp_id = 2;
        let role_id = 1;

        let val = delete_role(&db, emp_id, role_id).await;
        assert!(val.unwrap());

        let db_row = db
            .query_opt(
                "SELECT * FROM employee_role WHERE employee_id = $1 AND role_id = $2",
                &[&emp_id, &role_id],
            )
            .await;

        assert!(db_row.unwrap().is_none());
    }

    #[tokio::test]
    async fn test_delete_privilege() {
        let pool = initialize_db().await.unwrap();
        let db = pool.get().await.unwrap();

        // Invalid id
        let val = delete_privilege(&db, 20, 3).await;
        assert!(
            matches!(val, Err(ApiError::Error(err)) if err == "Employee with privilege id '20' does not exist")
        );

        // Verify role is deleted in db
        let emp_id = 2;
        let privilege_id = 1;

        let val = delete_privilege(&db, emp_id, privilege_id).await;
        assert!(val.unwrap());

        let db_row = db
            .query_opt(
                "SELECT * FROM employee_privilege WHERE employee_id = $1 AND privilege_id = $2",
                &[&emp_id, &privilege_id],
            )
            .await;

        assert!(db_row.unwrap().is_none());
    }
}
```
