```html
`list_task.stpl`
<div class="datgrd">
    <div class="datgrd__cnt">
        <div class="datgrd__headr">
            <div class="datgrd__hcol datgrd__hcol__w7">Project Name</div>
            <div class="datgrd__hcol datgrd__col__auto">Title</div>
            <div class="datgrd__hcol datgrd__hcol__w5">Assignee</div>
            <div class="datgrd__hcol datgrd__hcol__w5">Status</div>
            <div class="datgrd__hcol datgrd__hcol__w3">Priority</div>
            <div class="datgrd__hcol datgrd__hcol__w4">Due Date</div>
            <div class="datgrd__col datgrd__hcol__w3"></div>
            <div class="datgrd__col datgrd__hcol__w4"></div>
        </div>
        <% for item in items.iter() { %>
        <div class="datgrd__rows">
            <div class="datgrd__row">
                <div class="datgrd__col datgrd__col__w7">ProjectApp</div>
                <div class="datgrd__col datgrd__col__auto">Completed The New Project</div>
                <div class="datgrd__col datgrd__col__w5">Askar</div>
                <div class="datgrd__col datgrd__col__w5 ">
                    <span class="tag tag--blue">In-Progress</span>
                </div>
                <div class="datgrd__col datgrd__col__w3">High</div>
                <div class="datgrd__col datgrd__col__w4">12 Dec 2024</div>
                <div class="datgrd__col datgrd__hcol__w3">
                    <a class="datgrd__actn buttn buttn--small" href="#" title="Edit">
                        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-pencil-square" viewBox="0 0 16 16">
                            <path d="M15.502 1.94a.5.5 0 0 1 0 .706L14.459 3.69l-2-2L13.502.646a.5.5 0 0 1 .707 0l1.293 1.293zm-1.75 2.456-2-2L4.939 9.21a.5.5 0 0 0-.121.196l-.805 2.414a.25.25 0 0 0 .316.316l2.414-.805a.5.5 0 0 0 .196-.12l6.813-6.814z"/>
                            <path fill-rule="evenodd" d="M1 13.5A1.5 1.5 0 0 0 2.5 15h11a1.5 1.5 0 0 0 1.5-1.5v-6a.5.5 0 0 0-1 0v6a.5.5 0 0 1-.5.5h-11a.5.5 0 0 1-.5-.5v-11a.5.5 0 0 1 .5-.5H9a.5.5 0 0 0 0-1H2.5A1.5 1.5 0 0 0 1 2.5z"/>
                        </svg>
                    </a>
                </div>
                <div class="datgrd__col datgrd__hcol__w4">
                    <a class="datgrd__actn buttn buttn--small" href="#" title="Edit">
                        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-bricks" viewBox="0 0 16 16">
                            <path d="M0 .5A.5.5 0 0 1 .5 0h15a.5.5 0 0 1 .5.5v3a.5.5 0 0 1-.5.5H14v2h1.5a.5.5 0 0 1 .5.5v3a.5.5 0 0 1-.5.5H14v2h1.5a.5.5 0 0 1 .5.5v3a.5.5 0 0 1-.5.5H.5a.5.5 0 0 1-.5-.5v-3a.5.5 0 0 1 .5-.5H2v-2H.5a.5.5 0 0 1-.5-.5v-3A.5.5 0 0 1 .5 6H2V4H.5a.5.5 0 0 1-.5-.5zM3 4v2h4.5V4zm5.5 0v2H13V4zM3 10v2h4.5v-2zm5.5 0v2H13v-2zM1 1v2h3.5V1zm4.5 0v2h5V1zm6 0v2H15V1zM1 7v2h3.5V7zm4.5 0v2h5V7zm6 0v2H15V7zM1 13v2h3.5v-2zm4.5 0v2h5v-2zm6 0v2H15v-2z"/>
                        </svg>
                    </a>
                    <a class="datgrd__actn buttn buttn--small" href="#" title="Edit">
                        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-gear-fill" viewBox="0 0 16 16">
                            <path d="M9.405 1.05c-.413-1.4-2.397-1.4-2.81 0l-.1.34a1.464 1.464 0 0 1-2.105.872l-.31-.17c-1.283-.698-2.686.705-1.987 1.987l.169.311c.446.82.023 1.841-.872 2.105l-.34.1c-1.4.413-1.4 2.397 0 2.81l.34.1a1.464 1.464 0 0 1 .872 2.105l-.17.31c-.698 1.283.705 2.686 1.987 1.987l.311-.169a1.464 1.464 0 0 1 2.105.872l.1.34c.413 1.4 2.397 1.4 2.81 0l.1-.34a1.464 1.464 0 0 1 2.105-.872l.31.17c1.283.698 2.686-.705 1.987-1.987l-.169-.311a1.464 1.464 0 0 1 .872-2.105l.34-.1c1.4-.413 1.4-2.397 0-2.81l-.34-.1a1.464 1.464 0 0 1-.872-2.105l.17-.31c.698-1.283-.705-2.686-1.987-1.987l-.311.169a1.464 1.464 0 0 1-2.105-.872zM8 10.93a2.929 2.929 0 1 1 0-5.86 2.929 2.929 0 0 1 0 5.858z"/>
                        </svg>
                    </a>
                </div>
            </div>
        </div>
        <% } %>
    </div>
</div>

```

```html
`task_model`
<div class="datgrd">
    <div class="datgrd__cnt">
        <div class="datgrd__headr">
            <div class="datgrd__hcol datgrd__hcol__w7">Project Name</div>
            <div class="datgrd__hcol datgrd__col__auto">Title</div>
            <div class="datgrd__hcol datgrd__hcol__w5">Assignee</div>
            <div class="datgrd__hcol datgrd__hcol__w5">Status</div>
            <div class="datgrd__hcol datgrd__hcol__w3">Priority</div>
            <div class="datgrd__hcol datgrd__hcol__w4">Due Date</div>
            <div class="datgrd__col datgrd__hcol__w3"></div>
            <div class="datgrd__col datgrd__hcol__w4"></div>
        </div>
        <% for item in items.iter() { %>
        <div class="datgrd__rows">
            <div class="datgrd__row">
                <div class="datgrd__col datgrd__col__w7">ProjectApp</div>
                <div class="datgrd__col datgrd__col__auto">Completed The New Project</div>
                <div class="datgrd__col datgrd__col__w5">Askar</div>
                <div class="datgrd__col datgrd__col__w5 ">
                    <span class="tag tag--blue">In-Progress</span>
                </div>
                <div class="datgrd__col datgrd__col__w3">High</div>
                <div class="datgrd__col datgrd__col__w4">12 Dec 2024</div>
                <div class="datgrd__col datgrd__hcol__w3">
                    <a class="datgrd__actn buttn buttn--small" href="#" title="Edit">
                        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-pencil-square" viewBox="0 0 16 16">
                            <path d="M15.502 1.94a.5.5 0 0 1 0 .706L14.459 3.69l-2-2L13.502.646a.5.5 0 0 1 .707 0l1.293 1.293zm-1.75 2.456-2-2L4.939 9.21a.5.5 0 0 0-.121.196l-.805 2.414a.25.25 0 0 0 .316.316l2.414-.805a.5.5 0 0 0 .196-.12l6.813-6.814z"/>
                            <path fill-rule="evenodd" d="M1 13.5A1.5 1.5 0 0 0 2.5 15h11a1.5 1.5 0 0 0 1.5-1.5v-6a.5.5 0 0 0-1 0v6a.5.5 0 0 1-.5.5h-11a.5.5 0 0 1-.5-.5v-11a.5.5 0 0 1 .5-.5H9a.5.5 0 0 0 0-1H2.5A1.5 1.5 0 0 0 1 2.5z"/>
                        </svg>
                    </a>
                </div>
                <div class="datgrd__col datgrd__hcol__w4">
                    <a class="datgrd__actn buttn buttn--small" href="#" title="Edit">
                        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-bricks" viewBox="0 0 16 16">
                            <path d="M0 .5A.5.5 0 0 1 .5 0h15a.5.5 0 0 1 .5.5v3a.5.5 0 0 1-.5.5H14v2h1.5a.5.5 0 0 1 .5.5v3a.5.5 0 0 1-.5.5H14v2h1.5a.5.5 0 0 1 .5.5v3a.5.5 0 0 1-.5.5H.5a.5.5 0 0 1-.5-.5v-3a.5.5 0 0 1 .5-.5H2v-2H.5a.5.5 0 0 1-.5-.5v-3A.5.5 0 0 1 .5 6H2V4H.5a.5.5 0 0 1-.5-.5zM3 4v2h4.5V4zm5.5 0v2H13V4zM3 10v2h4.5v-2zm5.5 0v2H13v-2zM1 1v2h3.5V1zm4.5 0v2h5V1zm6 0v2H15V1zM1 7v2h3.5V7zm4.5 0v2h5V7zm6 0v2H15V7zM1 13v2h3.5v-2zm4.5 0v2h5v-2zm6 0v2H15v-2z"/>
                        </svg>
                    </a>
                    <a class="datgrd__actn buttn buttn--small" href="#" title="Edit">
                        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-gear-fill" viewBox="0 0 16 16">
                            <path d="M9.405 1.05c-.413-1.4-2.397-1.4-2.81 0l-.1.34a1.464 1.464 0 0 1-2.105.872l-.31-.17c-1.283-.698-2.686.705-1.987 1.987l.169.311c.446.82.023 1.841-.872 2.105l-.34.1c-1.4.413-1.4 2.397 0 2.81l.34.1a1.464 1.464 0 0 1 .872 2.105l-.17.31c-.698 1.283.705 2.686 1.987 1.987l.311-.169a1.464 1.464 0 0 1 2.105.872l.1.34c.413 1.4 2.397 1.4 2.81 0l.1-.34a1.464 1.464 0 0 1 2.105-.872l.31.17c1.283.698 2.686-.705 1.987-1.987l-.169-.311a1.464 1.464 0 0 1 .872-2.105l.34-.1c1.4-.413 1.4-2.397 0-2.81l-.34-.1a1.464 1.464 0 0 1-.872-2.105l.17-.31c.698-1.283-.705-2.686-1.987-1.987l-.311.169a1.464 1.464 0 0 1-2.105-.872zM8 10.93a2.929 2.929 0 1 1 0-5.86 2.929 2.929 0 0 1 0 5.858z"/>
                        </svg>
                    </a>
                </div>
            </div>
        </div>
        <% } %>
    </div>
</div>

```

```html
`req.stpl`

<% include!("../includes/page_header.stpl"); %>

<main class="contain">
	<div class="conthdr">
		<div class="conthdr__info">
			<h2 class="conthdr__title"><%= project.title %> - Requirements</h2>
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
				<li class="conthdr__bitem"><%= project.title %></li>
			</ol>
		</div>
		<div class="conthdr__action">
			<% if role_is_admin || role_is_qa || role_is_manager { %>
				<button type="button" class="buttn buttn--small" data-modal-show="modal-task-add">
					Add Task
				</button>
			<% } %>
			<a
				href="/<%= project.slug %>/design-system"
				title="Design System"
				class="buttn buttn--small"
			>
				Design System
			</a>
			<a
				href="/<%= project.slug %>/kb"
				title="Kb"
				class="buttn buttn--small"
			>
				Kb
			</a>
			<a
				href="/<%= project.slug %>/report"
				title="Report"
				class="buttn buttn--small"
			>
				Report
			</a>
			<% if role_is_admin { %>
			<button type="button" class="buttn buttn--small" data-modal-show="modal-req-add">
				Add Requirement
			</button>
			<% } %>
		</div>
	</div>

	<div class="reqlst">
		<div class="reqlst__cnt" id="content-req" >
			<% include!("../includes/list_requirement.stpl"); %>
		</div>
	</div>

</main>

<div class="modal__back">
<%
	let modal_title = "Add Requirement";
	let modal_id = "modal-req-add"; 
	let modal_replace = "content-req";
	let modal_is_edit = false;
	let modal_action = format!("/api/{}/requirement/create", project.slug); 
%>
<% include!("../includes/requirement_modal.stpl"); %>
<%
	let modal_title = "Add Task";
	let modal_id = "modal-task-add";
	let modal_is_edit = false;
	let modal_action = format!("/api/{}/task/create", project.slug); %>
<% include!("../includes/task_model.stpl"); %>
</div>

<% include!("../includes/page_footer.stpl"); %>

```

```html
`task.stpl`

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
	<div>
		<% include!("../includes/list_task.stpl"); %>
	</div>
</main>

<% include!("../includes/page_footer.stpl"); %>

```
