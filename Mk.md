```rust
pub async fn get_group_list(
    db: &DBConnection<'_>,
    user_id: i64,
    options: &TaskGetListOptions,
) -> Result<Vec<TaskItemGroup>, ApiError> {
    // Get the project ids of this user
    let mut query = "SELECT t.id, t.code, t.priority, t.title, t.status, t.module_id,
        t.version_id, t.assignee_id FROM task t"
        .to_string();

    let mut params: Vec<&(dyn ToSql + Sync)> = Vec::new();
    let mut where_clauses: Vec<String> = vec![];

    where_clauses.push("t.status != $1 AND t.status != $2".to_string());
    params.push(&"closed");
    params.push(&"rejected");

    // Filter based on assignee
    if let Some(assignee_id) = &options.assignee_id {
        query += " INNER JOIN task_assignee ta ON t.id = ta.task_id ";
        where_clauses.push(format!("ta.assignee_id = ${}", params.len() + 1));
        params.push(assignee_id);
    }

    // Filter only the employee projects
    let project_ids: Vec<i64> = project::get_all_by_employee(db, user_id).await?;
    where_clauses.push(format!("project_id = ANY(${})", params.len() + 1));
    params.push(&project_ids);

    // Filter based on search keyword
    let int_key: String;
    if let Some(key) = &options.keyword.clone() {
        where_clauses.push(format!(
            "(t.tags LIKE ${} OR t.title ~* ${} OR t.code ~* ${})",
            params.len() + 1,
            params.len() + 2,
            params.len() + 2,
        ));
        int_key = format!("%#{}#%", key);
        params.push(&int_key);
        params.push(&options.keyword);
        params.push(&options.keyword);
    }

    // Filter based on project id
    if let Some(project_id) = &options.project_id {
        where_clauses.push(format!("t.project_id = ${}", params.len() + 1));
        params.push(project_id)
    }

    let query = format!(
        "{} WHERE {} ORDER BY priority DESC, due_on;",
        query,
        where_clauses.join(" AND ")
    );

    let rows = db.query(&query, &params).await?;

    // Get all the status, priority, versions, modules, assignee and form maps
    let status_map = get_display_task_status();
    let priority_map = get_display_task_priority();
    let version_map = get_version_map(db).await?;
    let module_map = get_module_map(db).await?;
    let assignee_map = get_assignee_map(db).await?;

    let task_group_map = [
        ("open", "open"),
        ("in-progress", "in-progress"),
        ("paused", "in-progress"),
        ("waiting", "in-progress"),
        ("resolved", "to-review"),
        ("reviewed", "to-test"),
        ("verified", "to-release"),
        ("tested", "to-release"),
        ("reopened", "in-progress"),
    ]
    .iter()
    .map(|&el| (el.0.to_string(), el.1.to_string()))
    .collect::<HashMap<_, _>>();

    let mut items: Vec<TaskItemGroup> = vec![
        TaskItemGroup::new("open", "Open"),
        TaskItemGroup::new("in-progress", "In Progress"),
        TaskItemGroup::new("to-review", "To Review"),
        TaskItemGroup::new("to-test", "To Test"),
        TaskItemGroup::new("to-release", "To Release"),
    ];

    // Create status to group id map
    // Create empty groups and then form and add the group items
    for row in rows {
        let status: String = row.get("status");
        let group_id = task_group_map
            .get(&status)
            .unwrap_or(&"".to_string())
            .to_owned();
        if let Some(group) = items.iter_mut().find(|el| el.id == group_id) {
            // Form the assignee name
            let assignee = if let Some(assignee_id) = row.get::<_, Option<i64>>("assignee_id") {
                assignee_map
                    .get(&assignee_id)
                    .unwrap_or(&"Unknown".to_string())
                    .to_owned()
            } else {
                "Unknown".to_string()
            };

            // Form the task item
            let task = TaskItem {
                id: row.get("id"),
                code: row.get("code"),
                title: row.get("title"),
                version: version_map
                    .get(&row.get("version_id"))
                    .unwrap_or(&"Unknown".to_string())
                    .to_owned(),
                module: module_map
                    .get(&row.get("module_id"))
                    .unwrap_or(&"Unknown".to_string())
                    .to_owned(),
                status: status_map
                    .get(&status)
                    .unwrap_or(&"Unknown".to_string())
                    .to_owned(),
                assignee,
            };

            // Get or create priority group and add the task item
            let priority: i16 = row.get("priority");
            if let Some(priority_item) = group
                .priority_groups
                .iter_mut()
                .find(|el| el.priority == priority)
            {
                priority_item.tasks.push(task);
                priority_item.no_tasks += 1;
                group.no_tasks += 1;
            } else {
                group.priority_groups.push(TaskPriorityGroup {
                    priority,
                    display_priority: priority_map
                        .get(&priority)
                        .unwrap_or(&"Unknown".to_string())
                        .to_owned(),
                    no_tasks: 1,
                    tasks: vec![task],
                });
                group.no_tasks = 1;
            }
        }
    }

    Ok(items)
}
```
