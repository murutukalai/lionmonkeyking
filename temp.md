```html
<div id="<%= modal_id %>" class="modal modal--hidden">
    <% include!("../components/modal_header.stpl"); %>
    <div class="modal__cont">
        <form 
            id="form-<%= modal_id %>"
            action="<%= modal_action %>"
            method="post"
            class="form"
            data-form-trigger="modal-close#<%= modal_id %>"
        >
            <div class="modal__detl">
                <div class="form__row">
                    <div class="form__field ">
                        <label for="title" class="form__label">Title:</label>
                        <input id="title" class="form__input" type="text" name="title" required maxlength="128" value="" />
                    </div>
                </div>
                <div class="form__row">
                    <div class="form__field form__col1">
                        <label for="assignee_id" class="form__label">Assignee:</label>
                        <select class="form__selct" id="assignee_id" name="assignee_id">
                            <option value=""></option>
                            <% for assignee in task_assignees { %>
                            <option value="<%= assignee.id %>"><%= assignee.name %></option>
                            <% } %>
                        </select>
                    </div>
                    <div class="form__field form__col1">
                        <label for="priority" class="form__label">Priority:</label>
                        <select class="form__selct" id="priority" name="priority" value="">
                            <option value="4">Urgent</option>
                            <option value="3">High</option>
                            <option value="2">Medium</option>
                            <option value="1">Low</option>
                        </select>                            
                    </div>
                    <div class="form__field form__col1">
                        <label for="due_date" class="form__label">Due Date:</label>
                        <input id="due_date" class="form__input" type="date" name="due_date" required/>
                    </div>
                </div>
                <div class="form__row">
                    <div class="form__field">
                        <label for="description" class="form__label">Description:</label>
                        <textarea class="form__txtar" id="description" name="description" rows="4"></textarea>
                    </div>
                </div>
            </div>
            <div class="modal__footr">
                <button class="buttn" data-modal-trigger="hide">Cancel</button>
                <button class="buttn buttn--primary" type="submit">Save</button>
            </div>
        </form>
    </div>
</div>
```

task_emp
```html
<% include!("../includes/page_header.stpl"); %>

<main class="contain">
	<div class="conthdr">
		<div class="conthdr__info">
			<h2 class="conthdr__title">Task</h2>
			<ol class="conthdr__bcrum" aria-label="Breadcrumb">
				<li class="conthdr__bitem">
					<a class="conthdr__blink" href="/"> Home </a>
					<svg
						class="conthdr__barrw"
						xmlns="http://www.w3.org/2000/svg"
						width="24"
						height="24"
						viewBox="0 0 24 24"
						fill="none"
						stroke="currentColor"
						stroke-width="2"
						stroke-linecap="round"
						stroke-linejoin="round"
					>
						<path d="m9 18 6-6-6-6" />
					</svg>
				</li>
				<li class="conthdr__bitem">Task</li>
			</ol>
		</div>
	</div>
    <div class="datgrd__tit">Priority</div>
	<div class="datgrd">
		<div class="datgrd__cnt">
			<div class="datgrd__headr">
				<div class="datgrd__hcol datgrd__hcol__w5">Project Name</div>
                <div class="datgrd__hcol datgrd__col__auto">Title</div>
				<div class="datgrd__hcol datgrd__hcol__w4">Assignee</div>
				<div class="datgrd__hcol datgrd__hcol__w4">Status</div>
				<div class="datgrd__hcol datgrd__hcol__w3">Priority</div>
				<div class="datgrd__hcol datgrd__hcol__w4">Due Date</div>
				<div class="datgrd__col datgrd__hcol__w3"></div>
				<div class="datgrd__col datgrd__hcol__w4"></div>
			</div>
			
			<% for item in items.iter() {%>
            <% for task in item.tasks.iter() { %>
			<div class="datgrd__rows">
				<div class="datgrd__row">
					<div class="datgrd__col datgrd__col__w5"><%= task.project_title %></div>
					<div class="datgrd__col datgrd__col__auto"><%= task.title %></div>
					<div class="datgrd__col datgrd__col__w4"><%= task.assignee_name %></div>
					<div class="datgrd__col datgrd__col__w4">
                        <span class="tag tag--blue"><%= task.status %></span>
                    </div>
					<div class="datgrd__col datgrd__col__w3"><%= task.priority %></div>
					<div class="datgrd__col datgrd__col__w4"><%= task.due_date %></div>
					<div class="datgrd__col datgrd__hcol__w5">
						<button 
							type="button"
							class="datgrd__actn buttn buttn--small"  
							data-modal-edit="modal-task-edit"
							data-edit-url="/api/task/<%= task.id %>"
                    		data-edit-form="/api/task/<%= task.id %>"
						>
							<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-pencil-square" viewBox="0 0 16 16">
								<path d="M15.502 1.94a.5.5 0 0 1 0 .706L14.459 3.69l-2-2L13.502.646a.5.5 0 0 1 .707 0l1.293 1.293zm-1.75 2.456-2-2L4.939 9.21a.5.5 0 0 0-.121.196l-.805 2.414a.25.25 0 0 0 .316.316l2.414-.805a.5.5 0 0 0 .196-.12l6.813-6.814z"/>
								<path fill-rule="evenodd" d="M1 13.5A1.5 1.5 0 0 0 2.5 15h11a1.5 1.5 0 0 0 1.5-1.5v-6a.5.5 0 0 0-1 0v6a.5.5 0 0 1-.5.5h-11a.5.5 0 0 1-.5-.5v-11a.5.5 0 0 1 .5-.5H9a.5.5 0 0 0 0-1H2.5A1.5 1.5 0 0 0 1 2.5z"/>
							</svg>
						</button>
						<% if let Some(req_id) = task.requirement_id { %>
						<a class="datgrd__actn buttn buttn--small" href="/<%= task.project_slug %>/requirement/<%= req_id %>" title="Requirement">
							<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-bricks" viewBox="0 0 16 16">
								<path d="M0 .5A.5.5 0 0 1 .5 0h15a.5.5 0 0 1 .5.5v3a.5.5 0 0 1-.5.5H14v2h1.5a.5.5 0 0 1 .5.5v3a.5.5 0 0 1-.5.5H14v2h1.5a.5.5 0 0 1 .5.5v3a.5.5 0 0 1-.5.5H.5a.5.5 0 0 1-.5-.5v-3a.5.5 0 0 1 .5-.5H2v-2H.5a.5.5 0 0 1-.5-.5v-3A.5.5 0 0 1 .5 6H2V4H.5a.5.5 0 0 1-.5-.5zM3 4v2h4.5V4zm5.5 0v2H13V4zM3 10v2h4.5v-2zm5.5 0v2H13v-2zM1 1v2h3.5V1zm4.5 0v2h5V1zm6 0v2H15V1zM1 7v2h3.5V7zm4.5 0v2h5V7zm6 0v2H15V7zM1 13v2h3.5v-2zm4.5 0v2h5v-2zm6 0v2H15v-2z"/>
							</svg>
						</a>
						<% if let Some(technical_type) = &task.technical_type { %>
						<a class="datgrd__actn buttn buttn--small" href="/<%= task.project_slug %>/requirement/<%= req_id %>/technical-<%= technical_type %>" title="Technical">
							<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-gear-fill" viewBox="0 0 16 16">
								<path d="M9.405 1.05c-.413-1.4-2.397-1.4-2.81 0l-.1.34a1.464 1.464 0 0 1-2.105.872l-.31-.17c-1.283-.698-2.686.705-1.987 1.987l.169.311c.446.82.023 1.841-.872 2.105l-.34.1c-1.4.413-1.4 2.397 0 2.81l.34.1a1.464 1.464 0 0 1 .872 2.105l-.17.31c-.698 1.283.705 2.686 1.987 1.987l.311-.169a1.464 1.464 0 0 1 2.105.872l.1.34c.413 1.4 2.397 1.4 2.81 0l.1-.34a1.464 1.464 0 0 1 2.105-.872l.31.17c1.283.698 2.686-.705 1.987-1.987l-.169-.311a1.464 1.464 0 0 1 .872-2.105l.34-.1c1.4-.413 1.4-2.397 0-2.81l-.34-.1a1.464 1.464 0 0 1-.872-2.105l.17-.31c.698-1.283-.705-2.686-1.987-1.987l-.311.169a1.464 1.464 0 0 1-2.105-.872zM8 10.93a2.929 2.929 0 1 1 0-5.86 2.929 2.929 0 0 1 0 5.858z"/>
							</svg>
						</a>
						<% } %>
						<% } %>
					</div>
				</div>
            </div>
			<% } %>
			<% } %>
        </div>
    </div>
<div class="modal__back">

	<%
    let modal_title = "Edit Task";
    let modal_id = "modal-task-edit";
    let modal_is_edit = true;
    let modal_action = "/api/task/update"; 
	%>
	<% include!("../includes/task_modal.stpl"); %>
</div>
</main>

<% include!("../includes/page_footer.stpl"); %>


```
