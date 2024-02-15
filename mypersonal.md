```html
<div id="<%= modal_id %>" class="modal modal--hidden">
	<div class="modal__cont">
		<% include!("../components/modal_header.stpl"); %>
		<div class="modal__detl">
			<form
				id="form-<%= modal_id %>"
				action="<%= modal_action %>"
				method="post"
				data-form-trigger="modal-close#<%= modal_id %>"
				data-form-replace="content-doc"
				<% if !modal_is_edit && role_is_admin { %>
				enctype="multipart/form-data"
				<% } %>
				<% if modal_is_edit && role_is_admin { %>
					class="form"
				<% } %>
			>
			<% if modal_is_edit && role_is_admin { %>
				<div class="form__row">
					<div class="form__field form__col1">
						<label for="input-label" class="form__label"
							>Title:</label
						>
						<input
							type="text"
							name="filename"
							required
							id="filename"
							maxlength="125"
							class="form__input"
							placeholder="Enter Your Title"
						/>
					</div>
				</div>
				<% } %>
				<% if !modal_is_edit && role_is_admin { %>
				<div>
					<label>
						Upload file:
						<input type="file" name="file" multiple>
					</label>
				</div>
				<% } %>
				<% if modal_is_edit && role_is_admin { %>
				<div class="form__row">
					<div class="form__field form__col1">
						<label for="status" class="form__label">Status:</label>
						<select
							name="status"
							id="status"
							required
							class="form__selct"
						>
						<option value="D">Draft</option>
							<option value="R">Ready</option>
							<option value="A">Archived</option>
						</select>
					</div>
				</div>
				<% } %>
				<div class="modal__footr">
					<button class="buttn" data-modal-trigger="hide">
						Cancel
					</button>
					<button class="buttn buttn--primary" type="submit">
						Save
					</button>
				</div>
			</form>
		</div>
	</div>
</div>


//list doc

<% for doc in docs.iter() { %>
<a
    class="reqlst__itm"
    href="<%= doc.path %>"
>
    <span class="reqlst__info">
        <span class="reqlst__title">
            <%= doc.filename %>
        </span>
        <span class="reqlst__desc">
            <span class="tag tag--<%= doc.status | lower %>"><%= doc.status %></span>
        </span>
    </span>
    <% if role_is_admin || role_is_qa { %>
        <button
            type="button"
            class="buttn buttn--small"
            data-modal-edit="modal-doc-edit"
            data-edit-url="/api/<%= project.slug %>/requirement/<%= requirement.id %>/document/<%= doc.id %>"
            data-edit-form="/api/<%= project.slug %>/requirement/<%= requirement.id %>/document/<%= doc.id %>"
            data-edit-replace="content-doc"
        >Edit</button>
    <% } %>
</a>
<% } %>

// usecase

<% let
	modal_title = "Add Document"; 
	let modal_id = "modal-doc-add";
	let modal_is_edit = false; 
	let modal_action = format!("/api/{}/requirement/{}/document/upload", project.slug,requirement.id); %> 
<% include!("../includes/document_model.stpl"); %>

<% let
	modal_title = "Edit Document"; 
	let modal_id = "modal-doc-edit";
	let modal_is_edit = true; 
	let modal_action = format!("/api/{}/requirement/{}/document/update", project.slug,requirement.id); %> 
<% include!("../includes/document_model.stpl"); %>
```
