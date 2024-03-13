## privilege
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

