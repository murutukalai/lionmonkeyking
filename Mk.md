```rust
async fn handler_get(
    db: &DBConnection<'_>,
    task_id: i64,
    template_id: i64,
    is_copy: bool,
) -> RestResult<RestContentResponse> {
    let (template_id, item) = if task_id == 0 {
        (
            template_id,
            task::common::get_details_by_template_id(db, template_id).await?,
        )
    } else if task_id != 0 && is_copy {
        task::common::copy_details_by_id(db, task_id).await?
    } else {
        (template_id, task::common::get_by_id(db, task_id).await?)
    };
    let assignee_options = project_member::get_all_members(db, item.project_id).await?;
    let version_options = version::get_all_options(db, item.project_id).await?;
    let module_options = module::get_all_options(db, item.project_id).await?;
    let milestone_options = milestone::get_all_options(db, item.project_id).await?;
    let mut tag_options = tag::get_all_options(db, item.project_id).await?;
    tag_options.retain(|el| !item.tags.contains(&el.title.to_lowercase()));

    let role_options = vec![
        OptionItemString {
            id: "Developer".to_string(),
            title: "Developer".to_string(),
        },
        OptionItemString {
            id: "QA".to_string(),
            title: "QA".to_string(),
        },
        OptionItemString {
            id: "Reviewer".to_string(),
            title: "Reviewer".to_string(),
        },
        OptionItemString {
            id: "Designer".to_string(),
            title: "Designer".to_string(),
        },
        OptionItemString {
            id: "Member".to_string(),
            title: "Member".to_string(),
        },
    ];
    let priority_options = vec![
        OptionItem {
            id: 1,
            title: "Low".to_string(),
        },
        OptionItem {
            id: 2,
            title: "Normal".to_string(),
        },
        OptionItem {
            id: 3,
            title: "High".to_string(),
        },
        OptionItem {
            id: 4,
            title: "Urgent".to_string(),
        },
    ];

    let action_url = if item.id == 0 {
        format!("api/task/{}/create", item.project_id).to_string()
    } else {
        format!("api/task/{}/edit", task_id)
    };

    let ctx = TemplateTaskModal {
        action_url,
        item,
        role_options,
        assignee_options,
        version_options,
        module_options,
        milestone_options,
        priority_options,
        tag_options,
        template_id,
    };

    Ok(Json(RestContentResponse {
        success: true,
        content: Some(ctx.render_once().unwrap()),
        error: None,
    }))
}
```
```rust

pub async fn copy_details_by_id(
    db: &DBConnection<'_>,
    task_id: i64,
) -> Result<(i64, TaskInfo), ApiError> {
    let Some(row) = db
        .query_opt(
            "SELECT t.*, p.title AS project_title, p.code AS project_code
            FROM task t INNER JOIN project p ON p.id = t.project_id
            WHERE t.id = $1",
            &[&task_id],
        )
        .await?
    else {
        return Err(ApiError::Error(format!(
            "Task with id '{}' does not exist",
            task_id
        )));
    };

    let project_id: i64 = row.get("project_id");
    let type_value: String = row.get("type");
    let code = form_code(
        row.get("project_code"),
        get_next_code(db, project_id).await?,
    );

    let mut tags: Vec<String> = vec![];
    if let Some(tag) = row.get::<_, Option<&str>>("tags") {
        tags = helper::tag::to_list(tag);
    }

    let Ok(template_row) = db
        .query_one(
            "SELECT id FROM project_task_template WHERE project_id = $1 AND type = $2 LIMIT 1",
            &[&project_id, &type_value],
        )
        .await
    else {
        return Err(ApiError::Error(format!(
            "Unable to get the template of task with id '{}'",
            task_id
        )));
    };
    let template_id = template_row.get("id");
    let assignees = get_all_assignee(db, task_id).await?;

    Ok((
        template_id,
        TaskInfo {
            id: 0,
            milestone_id: row.get("milestone_id"),
            module_id: row.get("module_id"),
            version_id: row.get("version_id"),
            project_id,
            project_title: row.get("project_title"),
            priority: row.get("priority"),
            code,
            title: row.get("title"),
            type_value: row.get("type"),
            content: row.get("content"),
            tags,
            due_on: row
                .get::<_, NaiveDate>("due_on")
                .format("%Y-%m-%d")
                .to_string(),
            duration: row.get("duration"),
            requirement_id: row.get("requirement_id"),
            assignees,
        },
    ))
}
```
