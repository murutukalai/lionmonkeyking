```html
<div id="<%= modal_id %>" class="modal modal--hidden">
    <% include!("../components/modal_header.stpl"); %>
    <div class="modal__cont">
            <div class="modal__detl">
                <form 
                    id="form-<%= modal_id %>"
                    action="<%= modal_action %>"
                    method="post"
                    class="form"
                    data-form-trigger="modal-close#<%= modal_id %>"
                >
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
                                    <% for assignee in assignee_vec.iter() { %>
                                        <option value="<%= assignee.id %>"><%= assignee.name %></option>
                                        <% } %>
                                </select>
                            </div>
                            <div class="form__field form__col1">
                                <label for="priority" class="form__label">Priority:</label>
                                <select class="form__selct" id="priority" name="priority">
                                    <option value="U">Urgent</option>
                                    <option value="H">High</option>
                                    <option value="M">Medium</option>
                                    <option value="L">Low</option>
                                </select>                            
                            </div>
                            <div class="form__field form__col1">
                                <label for="due_date" class="form__label">Due Date:</label>
                                <input id="due_date" class="form__input" type="date" name="due_date" required value="" />
                            </div>
                        </div>
                        <div class="form__row">
                            <div class="form__field">
                                <label for="description" class="form__label">Description:</label>
                                <textarea class="form__txtar" id="description" rows="4"></textarea>
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
</div>

// req || 29 -> <% if role_is_admin || role_is_qa || role_is_manager { %>
				<button type="button" class="buttn buttn--small" data-modal-show="modal-task-add">
					Add Task
				</button>
			<% } %>

usecase || 138 -->	let modal_action = format!("/api/{}/requirement/{}/task/create", project.slug, requirement.id); %>
```
