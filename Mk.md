```rust
// Rest - Company - Document

use axum::{
    extract::{Multipart, Path},
    Extension, Json,
};
use backend_api::{
    company::document::{
        self, DocumentCreateInput, DocumentDetail, DocumentGetListOptions, DocumentInfo,
    },
    ApiListResponse, DBConnection,
};
use sailfish::TemplateOnce;
use serde::Deserialize;

use crate::{
    route::rest::{
        convert, helper, RestAuthUser, RestCommonResponse, RestContentResponse, RestResult,
    },
    state::ExtAppState,
};

#[cfg(not(feature = "with-s3"))]
use crate::route::rest::RestError;

#[cfg(not(feature = "with-s3"))]
use std::env;

#[cfg(not(feature = "with-s3"))]
use std::{fs, path};

#[derive(Debug, Deserialize)]
pub struct RestDocumentGetListOptions {
    keyword: Option<String>,
    show_all: Option<String>,
    page_no: String,
    sort_by: Option<String>,
    sort_asc: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct RestDocumentUpdateInput {
    title: Option<String>,
    tags: Option<Vec<String>>,
    version: Option<String>,
}

#[derive(TemplateOnce)]
#[template(path = "includes/company/document_grid.stpl")]
pub struct TemplateDocumentGrid {
    grid: ApiListResponse<DocumentDetail>,
    has_edit_access: bool,
    has_delete_access: bool,
    has_archive_access: bool,
    from_row: i64,
    to_row: i64,
}

pub async fn handler_grid(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
    Json(options): Json<RestDocumentGetListOptions>,
) -> RestResult<RestContentResponse> {
    let db = app_state.db.conn().await?;

    user.acl
        .check_privilege(&db, user.id, "company", "document", "view", None)
        .await?;

    let api_input = DocumentGetListOptions {
        keyword: convert::to_string_optional(&options.keyword),
        show_all: Some(convert::to_bool_optional(&options.show_all) == Some(true)),
        sort_by: convert::to_string_optional(&options.sort_by),
        sort_asc: convert::to_bool_optional(&options.sort_asc),
        page_no: convert::to_i64(&options.page_no, "Unable to convert page number")?,
    };

    let grid = document::get_list(&db, &api_input).await?;
    let (from_row, to_row) = helper::calc_row(grid.total_rows, grid.page_no);

    let ctx = TemplateDocumentGrid {
        grid,
        from_row,
        to_row,
        has_edit_access: user
            .get_acl()
            .has_privilege("company", "document", "edit", None),
        has_delete_access: user
            .get_acl()
            .has_privilege("company", "document", "delete", None),
        has_archive_access: user
            .get_acl()
            .has_privilege("company", "document", "archive", None),
    };

    Ok(Json(RestContentResponse {
        success: true,
        content: Some(ctx.render_once().unwrap()),
        error: None,
    }))
}

pub async fn handler_create(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
    mut multipart: Multipart,
) -> RestResult<RestCommonResponse> {
    let db = app_state.db.conn().await?;
    user.acl
        .check_privilege(&db, user.id, "company", "document", "add", None)
        .await?;
    let mut api_input = DocumentCreateInput {
        created_by_id: user.id,
        created_by: user.name,
        title: String::new(),
        tags: None,
        size: String::new(),
        file_type: String::new(),
        file_path: String::new(),
        version: 0,
    };
    let mut tags = vec![];
    while let Some(mut field) = multipart.next_field().await.unwrap() {
        match field.name() {
            #[cfg(not(feature = "with-s3"))]
            Some("file") => {
                if field.file_name().is_some() && Some("") != field.file_name() {
                    let cur_dir =
                        env::current_dir().map_err(|err| RestError::Error(format!("{}", err)))?;
                    let Some(cur_dir) = cur_dir.to_str() else {
                        return Err(RestError::Error(
                            "Unable to get current directory".to_string(),
                        ));
                    };

                    if !path::Path::new(&format!("{cur_dir}/public/documents")).exists() {
                        let Ok(_) = fs::create_dir(format!("{cur_dir}/public/documents")) else {
                            tracing::error!("Unable to create dir");
                            return Err(RestError::Error("UNSUPPORTED_MEDIA_TYPE".to_string()));
                        };
                    };

                    let store =
                        storage::DocumentStore::create(&format!("{}/public/documents", cur_dir))?;
                    let doc_infos = store.create_documents(&mut field, "/company_doc").await?;
                    if let Some(doc) = doc_infos.first() {
                        api_input.file_path = format!("{}/{}", doc.file_path, doc.file_name);
                        api_input.size = doc.size.clone();
                    }
                }
            }

            #[cfg(feature = "with-s3")]
            Some("file") => {
                if field.file_name().is_some() && Some("") != field.file_name() {
                    let store = storage::DocumentStore::create("documents").unwrap();
                    let doc_infos = store.create_documents(&mut field, "company_doc/").await?;
                    if let Some(doc) = doc_infos.first() {
                        api_input.file_path =
                            format!("{}{}", doc.file_name.clone(), doc.file_path.clone());
                        api_input.size = doc.size.clone();
                    }
                }
            }
            Some("title") => {
                api_input.title = field.text().await?;
            }
            Some("tags") => tags.push(field.text().await?),
            Some("version") => {
                api_input.version =
                    convert::to_i16(&field.text().await?, "Unable to convert version")?;
            }
            _ => {}
        }
    }
    api_input.tags = if tags.is_empty() { None } else { Some(tags) };
    let document_id = document::create(&db, &api_input).await?;
    Ok(Json(RestCommonResponse {
        success: document_id != 0,
        error: None,
    }))
}

pub async fn handler_update(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
    Path(document_id): Path<i64>,
    Json(input): Json<RestDocumentUpdateInput>,
) -> RestResult<RestCommonResponse> {
    let db = app_state.db.conn().await?;
    user.acl
        .check_privilege(&db, user.id, "company", "document", "edit", None)
        .await?;

    let title = input.title;
    let tags = input.tags;
    let version = convert::to_i16_optional(&input.version, "Unable to convert the version")?;
    let success = document::update(&db, document_id, &title, &tags, &version).await?;

    Ok(Json(RestCommonResponse {
        success,
        error: None,
    }))
}

#[derive(TemplateOnce)]
#[template(path = "includes/company/document_modal.stpl")]
pub struct TemplateDocumentModal {
    action_url: String,
    item: DocumentInfo,
}

pub async fn handler_get(
    db: &DBConnection<'_>,
    document_id: i64,
) -> RestResult<RestContentResponse> {
    let item = if document_id != 0 {
        document::get_by_id(db, document_id).await?
    } else {
        DocumentInfo {
            id: 0,
            title: String::new(),
            file_path: String::new(),
            version: 0,
            tags: vec![],
        }
    };
    let action_url = if document_id != 0 {
        format!("/api/company/document/{}", document_id)
    } else {
        "/api/company/document/create".to_string()
    };

    let ctx = TemplateDocumentModal { action_url, item };
    Ok(Json(RestContentResponse {
        success: true,
        error: None,
        content: Some(ctx.render_once().unwrap()),
    }))
}

pub async fn handler_get_create(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
) -> RestResult<RestContentResponse> {
    let db = app_state.db.conn().await?;
    user.acl
        .check_privilege(&db, user.id, "company", "document", "add", None)
        .await?;

    handler_get(&db, 0).await
}

pub async fn handler_get_edit(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
    Path(document_id): Path<i64>,
) -> RestResult<RestContentResponse> {
    let db = app_state.db.conn().await?;
    user.acl
        .check_privilege(&db, user.id, "company", "document", "edit", None)
        .await?;

    handler_get(&db, document_id).await
}

pub async fn handler_delete(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
    Path(document_id): Path<i64>,
) -> RestResult<RestCommonResponse> {
    let db = app_state.db.conn().await?;

    user.acl
        .check_privilege(&db, user.id, "company", "document", "delete", None)
        .await?;

    let file_path = document::get_by_id(&db, document_id).await?.file_path;

    #[cfg(not(feature = "with-s3"))]
    let cur_dir = env::current_dir().map_err(|err| RestError::Error(format!("{}", err)))?;

    #[cfg(not(feature = "with-s3"))]
    let Some(cur_dir) = cur_dir.to_str() else {
        return Err(RestError::Error(
            "Unable to get current directory".to_string(),
        ));
    };

    #[cfg(not(feature = "with-s3"))]
    let store = storage::DocumentStore::create(&format!("{}/public/documents", cur_dir))?;

    #[cfg(not(feature = "with-s3"))]
    store.delete(file_path.as_str()).await?;

    #[cfg(feature = "with-s3")]
    let store = storage::DocumentStore::create("documents").unwrap();
    #[cfg(feature = "with-s3")]
    store.delete(file_path.as_str()).await?;

    let success = document::delete_by_id(&db, document_id).await?;
    Ok(Json(RestCommonResponse {
        success,
        error: None,
    }))
}

pub async fn handler_archive(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
    Path(document_id): Path<i64>,
) -> RestResult<RestCommonResponse> {
    let db = app_state.db.conn().await?;

    user.acl
        .check_privilege(&db, user.id, "company", "document", "archive", None)
        .await?;

    let success = document::update_archive(&db, document_id).await?;

    Ok(Json(RestCommonResponse {
        success,
        error: None,
    }))
}
```

main grid
```html
<div class="dtgrd">
	<div class="dtgrd__innr">
		<div class="dtgrd__cnt">
			<div class="dtgrd__headr">
				<div
					ui-data-grid-col="id"
					class="dtgrd__hcol dtgrd__hcol__w3<% if grid.sort_by == "id" { %> dtgrd__hcol__activ<% } %>"
				>
					<span class="dtgrd__title">ID</span>
					<div class="dtgrd__hicn<% if !grid.sort_asc { %> dtgrd__hicn--desc<% } %>">
						<button type="button" class="buttn__icn"><i class="ic ic-chevron-up"></i></button>
                    	<button type="button" class="buttn__icn"><i class="ic ic-chevron-down"></i></button>
					</div>
				</div>
				<div
					ui-data-grid-col="title"
					class="dtgrd__hcol dtgrd__col__auto<% if grid.sort_by == "title" { %> dtgrd__hcol__activ<% } %>"
				>
					<span class="dtgrd__title">Title</span>
					<div class="dtgrd__hicn<% if !grid.sort_asc { %> dtgrd__hicn--desc<% } %>">
						<button type="button" class="buttn__icn"><i class="ic ic-chevron-up"></i></button>
                    	<button type="button" class="buttn__icn"><i class="ic ic-chevron-down"></i></button>
					</div>
				</div>
                <div
					ui-data-grid-col="type"
					class="dtgrd__hcol dtgrd__hcol__w5<% if grid.sort_by == "type" { %> dtgrd__hcol__activ<% } %>"
				>
					<span class="dtgrd__title">Type</span>
					<div class="dtgrd__hicn<% if !grid.sort_asc { %> dtgrd__hicn--desc<% } %>">
						<button type="button" class="buttn__icn"><i class="ic ic-chevron-up"></i></button>
                    	<button type="button" class="buttn__icn"><i class="ic ic-chevron-down"></i></button>
					</div>
				</div>
                <div
					ui-data-grid-col="created_on"
					class="dtgrd__hcol dtgrd__hcol__w5<% if grid.sort_by == "created_on" { %> dtgrd__hcol__activ<% } %>"
				>
					<span class="dtgrd__title">Created On</span>
					<div class="dtgrd__hicn<% if !grid.sort_asc { %> dtgrd__hicn--desc<% } %>">
						<button type="button" class="buttn__icn"><i class="ic ic-chevron-up"></i></button>
                    	<button type="button" class="buttn__icn"><i class="ic ic-chevron-down"></i></button>
					</div>
				</div>
                <div
					ui-data-grid-col="size"
					class="dtgrd__hcol dtgrd__hcol__w5<% if grid.sort_by == "size" { %> dtgrd__hcol__activ<% } %>"
				>
					<span class="dtgrd__title">Size</span>
					<div class="dtgrd__hicn<% if !grid.sort_asc { %> dtgrd__hicn--desc<% } %>">
						<button type="button" class="buttn__icn"><i class="ic ic-chevron-up"></i></button>
                    	<button type="button" class="buttn__icn"><i class="ic ic-chevron-down"></i></button>
					</div>
				</div>
                <div
					ui-data-grid-col="version"
					class="dtgrd__hcol dtgrd__hcol__w5<% if grid.sort_by == "version" { %> dtgrd__hcol__activ<% } %>"
				>
					<span class="dtgrd__title">Version</span>
					<div class="dtgrd__hicn<% if !grid.sort_asc { %> dtgrd__hicn--desc<% } %>">
						<button type="button" class="buttn__icn"><i class="ic ic-chevron-up"></i></button>
                    	<button type="button" class="buttn__icn"><i class="ic ic-chevron-down"></i></button>
					</div>
				<div class="dtgrd__hcol dtgrd__hcol__w6"></div>
			</div>
			</div>
			<div class="dtgrd__rows">
				<% for item in grid.items.iter() { %>
					<div class="dtgrd__row">
						<div class="dtgrd__col dtgrd__col__w3"><%= item.id %></div>
						<div class="dtgrd__col dtgrd__col__auto"><%= item.title %></div>
						<div class="dtgrd__col dtgrd__col__w5"><%= item.file_type %></div>
                        <div class="dtgrd__col dtgrd__col__w5"><%= item.created_on %></div>
                        <div class="dtgrd__col dtgrd__col__w5"><%= item.size %></div>
                        <div class="dtgrd__col dtgrd__col__w5"><%= item.version %></div>
						<div class="dtgrd__col dtgrd__col__w6 dtgrd__actn">
							<% if has_edit_access { %>
							<button class="buttn buttn--smaller" type="button" ui-action-modal="/api/company/document/<%= item.id %>">
								<i class="ic ics-edit"></i>
							</button>
							<% } %>
							<% if has_archive_access && item.active { %>
                            <button class="buttn buttn--smaller" type="button" ui-action-modal="/api/company/document/<%= item.id %>/archive">
								<i class="ic ic-archive-in"></i>
							</button>
							<% } %>
							<% if has_delete_access { %>
								<button class="buttn buttn--smaller"
								type="button"
								ui-action-get="/api/company/document/<%= item.id %>/delete"
								ui-action-complete="grid-reload"
								ui-action-grid="grid-holiday"
								ui-action-confirm="Do you want to delete this holiday ?"
							>
								<i class="ic ic-trash"></i>
							</button>
							<% } %>
							<% if has_edit_access { %>
								<button class="buttn buttn--smaller" type="button" ui-action-modal="/api/company/document/<%= item.id %>">
								<i class="ic ic-cloud-download"></i>
							</button>
							<% } %>
						</div>
					</div>
                <% } %>
			</div>
			<% if grid.items.is_empty() { %>
				<% include!("../../includes/base/empty_data.stpl"); %>
			<% } %>
		</div>
	</div>
	<% include!("../../includes/base/datagird_pagination.stpl"); %>
</div>
```

model
```html
<div class="modal">
	<div class="modal__cont">
		<div class="modal__head">
			<div class="modal__htit">
				<% if item.id == 0 { %>Add Document<% } else { %>Edit Document<% } %>				
			</div>
			<button class="modal__hclose" ui-modal-action="close">
				<i class="ic ic-x ic-sm"></i>
			</button>
		</div>
		<form class="form"
			method="post"
			action="<%= action_url %>"
			ui-form-complete="grid-reload,modal-close"
			ui-form-grid="grid-document"
            <% if item.id == 0 { %>
                enctype="multipart/form-data"
                ui-form-enctype="multipart/form-data"
            <% } %>
		>
			<div class="modal__detl">
				<div class="form__row">
                    <div class="form__field">
						<label for="file" class="form__label">File:</label>
						<input type="file" name="file" />
					</div>
				</div>
                <div class="form__row">
                    <div class="form__field">
						<label for="title" class="form__label">Title:</label>
						<input class="form__input" ui-validation="required" maxlength="64" id="title" type="text" name="title" value="<%= item.title %>"/>
					</div>
				</div>
				<div class="form__row">
					<div class="form__field form__col1">
						<label for="version" class="form__label">Version No:</label>
						<input class="form__input" ui-validation="required" maxlength="5"
                            id="version" type="number" name="version" value="<%= item.version %>" />
					</div>
                    <div class="form__field form__col1">
                        <label for="tags" class="form__label">Tags:</label>
                        <select
							name="tags[]"
							id="tags"
							multiple
							class="form__selct"
							ui-form-select-type="tags"
						>
							<option value="" data-placeholder="true">Select Tags</option>
							<% for tag in item.tags { %>
                                <option value="<%= tag %>" selected="selected"><%= tag %></option>
                            <% } %>
						</select>
                    </div>
				</div>
			</div>
			<div class="modal__footr">
				<button class="buttn" type="button" ui-modal-action="close">Cancel</button>
				<button class="buttn buttn--primary" type="submit">Save</button>
			</div>
		</form>
	</div>
</div>
```
page
```html
<% include!("../../includes/page_header.stpl"); %>

<main class="page__cont">
	<div class="page__inner">
		<div class="cthdr">
			<div class="cthdr__contnt">
				<div class="cthdr__info">
					<div class="cthdr__title">Company - Document</div>
				</div>
                <% if has_add_access { %>
				<div class="cthdr__actin">
					<button class="buttn buttn--small" type="button" ui-action-modal="/api/company/document/create">Add Document</button>
				</div>
                <% } %>
			</div>
		</div>
		<div class="page__inner__cntr">
            <div class="contnr">
				<div class="fltbar">
                    <div class="fltbar__cnt">
                        <div class="fltbar__main">
                            <form
                                id="form-document"
                                action="/api/company/document"
                                method="post"
                            >
                                <div class="fltbar__crts">
                                    <div class="fltbar__searc">
										<input
											placeholder="Search..."
											type="text"
											class="fltbar__input fltbar__searc__clear"
											name="keyword"
											maxlength="64"
											value=""
										/>
										<div class="fltbar__sercl fltbar__sercl--hidden">
											<i class="ic ic-x ic-sm"></i>
										</div>
									</div>
									<div class="fltbar__chkbx">
										<input
											type="checkbox"
											class="fltbar__chkbx__activ"
											id="show_all"
											name="show_all"
											value="true"
										/>
										<label for="show_all" class="fltbar__chkbx__lbl"
											>Show All</label
										>
									</div>
                                    <div class="fltbar__actns">
                                        <button class="buttn buttn--small buttn--primary" type="submit">
                                            Search
                                        </button>
                                    </div>
                                </div>
                            </form>
                        </div>
                    </div>
                </div>
				<div id="grid-document" ui-data-grid="form-document"></div>
			</div>
		</div>
    </div>
</main>

<% include!("../../includes/page_footer.stpl"); %>

```

```rust
// Api - Company - Documents

use chrono::NaiveDateTime;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use tokio_postgres::types::ToSql;

use crate::{helper, ApiError, ApiListResponse, DBConnection, GRID_ROWS_PER_PAGE};

/* Constant */

/* Structs */

#[derive(Debug, Deserialize)]
pub struct DocumentGetListOptions {
    pub keyword: Option<String>,
    pub show_all: Option<bool>,
    pub page_no: i64,
    pub sort_by: Option<String>,
    pub sort_asc: Option<bool>,
}

#[derive(Debug, Serialize)]
pub struct DocumentDetail {
    pub id: i64,
    pub title: String,
    pub size: String,
    pub file_type: String,
    pub version: i16,
    pub tags: Vec<String>,
    pub active: bool,
    pub file_path: String,
    pub created_on: String,
    pub created_by: String,
}

#[derive(Debug, Serialize)]
pub struct DocumentInfo {
    pub id: i64,
    pub title: String,
    pub version: i16,
    pub file_path: String,
    pub tags: Vec<String>,
}

#[derive(Debug, Deserialize)]
pub struct DocumentCreateInput {
    pub created_by_id: i64,
    pub created_by: String,
    pub title: String,
    pub tags: Option<Vec<String>>,
    pub size: String,
    pub file_type: String,
    pub version: i16,
    pub file_path: String,
}

/* Private Functions */

/* Public Functions */

pub async fn get_list(
    db: &DBConnection<'_>,
    options: &DocumentGetListOptions,
) -> Result<ApiListResponse<DocumentDetail>, ApiError> {
    let mut query = " FROM company_document".to_string();
    let mut params: Vec<&(dyn ToSql + Sync)> = Vec::new();
    let mut where_clauses: Vec<String> = vec![];

    let int_key: String;
    if let Some(key) = &options.keyword.clone() {
        if !key.is_empty() {
            where_clauses.push(format!(
                "(tags LIKE ${} OR title ~* ${})",
                params.len() + 1,
                params.len() + 2
            ));
            int_key = format!("%#{}#%", key);
            params.push(&int_key);
            params.push(&options.keyword);
        }
    }

    if let Some(active) = &options.show_all {
        if !active {
            where_clauses.push("is_active = 'T'".to_owned())
        }
    } else {
        where_clauses.push("is_active != 'F'".to_owned())
    }

    if !where_clauses.is_empty() {
        query += " WHERE ";
        query += where_clauses.join(" AND ").as_str();
    }

    // Get the count and calculate pages
    let mut count: i64 = 0;
    let mut page_no: i64 = options.page_no;
    if let Ok(row) = db
        .query_one(&format!("SELECT COUNT(id) AS count {}", query), &params)
        .await
    {
        count = row.get(0)
    }

    let ret_sort_by: String;
    let ret_sort_asc: bool;

    if let (Some(sort_by), Some(sort_asc)) = (&options.sort_by, &options.sort_asc) {
        ret_sort_by = sort_by.clone();
        ret_sort_asc = *sort_asc;
        let sort_map = HashMap::from([
            ("id", "id"),
            ("title", "title"),
            ("type", "type"),
            ("version", "version"),
            ("size", "size"),
            ("is_active", "is_active"),
            ("created_by", "created_by"),
            ("created_on", "created_on"),
        ]);

        if let Some(key) = sort_map.get(sort_by.as_str()) {
            let sort_order = if *sort_asc { "ASC" } else { "DESC" };
            query += &format!(" ORDER BY {} {}", key, sort_order);
        }
    } else {
        query += " ORDER BY id ASC";
        ret_sort_by = "id".to_string();
        ret_sort_asc = true;
    }

    // If no records found, return empty result
    if count == 0 {
        return Ok(ApiListResponse {
            items: vec![],
            total_rows: 0,
            total_pages: 0,
            page_no: 1,
            sort_by: ret_sort_by,
            sort_asc: ret_sort_asc,
        });
    }

    let mut total_pages: i64 = count / GRID_ROWS_PER_PAGE;
    if count % GRID_ROWS_PER_PAGE > 0 {
        total_pages += 1;
    }

    if page_no > total_pages {
        page_no = total_pages;
    }

    query = format!(
        "SELECT * {} LIMIT {} OFFSET {}",
        query,
        GRID_ROWS_PER_PAGE,
        (page_no - 1) * GRID_ROWS_PER_PAGE
    );

    let rows = db.query(&query, &params).await?;
    let mut items: Vec<DocumentDetail> = vec![];
    for row in rows {
        let tags = if let Some(tags) = row.get::<_, Option<String>>("tags") {
            helper::tag::to_list(&tags)
        } else {
            vec![]
        };
        items.push(DocumentDetail {
            id: row.get("id"),
            title: row.get("title"),
            size: row.get("size"),
            file_type: row.get("type"),
            version: row.get("version"),
            tags,
            active: row.get("is_active"),
            file_path: row.get("file_path"),
            created_on: row
                .get::<_, NaiveDateTime>("created_on")
                .format("%Y-%m-%d")
                .to_string(),
            created_by: row.get("created_by"),
        });
    }

    Ok(ApiListResponse {
        items,
        total_rows: count,
        total_pages,
        page_no,
        sort_by: ret_sort_by,
        sort_asc: ret_sort_asc,
    })
}

pub async fn get_by_id(db: &DBConnection<'_>, document_id: i64) -> Result<DocumentInfo, ApiError> {
    let rows = db
        .query(
            "SELECT * FROM company_document WHERE id = $1",
            &[&document_id],
        )
        .await?;

    let Some(row) = rows.first() else {
        return Err(ApiError::Error(format!(
            "Document with id '{}' does not exist",
            document_id
        )));
    };

    let mut tags: Vec<String> = vec![];
    if let Some(tag) = row.get::<_, Option<&str>>("tags") {
        tags = helper::tag::to_list(tag);
    }

    Ok(DocumentInfo {
        id: row.get("id"),
        title: row.get("title"),
        version: row.get("version"),
        file_path: row.get("file_path"),
        tags,
    })
}

pub async fn create(db: &DBConnection<'_>, input: &DocumentCreateInput) -> Result<i64, ApiError> {
    let mut input_tags: Option<String> = None;
    if let Some(tags) = &input.tags {
        input_tags = Some(helper::tag::to_string(tags));
    }

    let params: Vec<&(dyn ToSql + Sync)> = vec![
        &input.created_by_id,
        &input.created_by,
        &input.title,
        &input.file_type,
        &input.version,
        &input_tags,
        &input.size,
        &true,
        &input.file_path,
    ];

    let row = db
        .query_one(
            r#"INSERT INTO company_document
            (created_by_id, created_by, title, type, version, tags, size, is_active, file_path)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) 
            RETURNING ID"#,
            &params,
        )
        .await?;

    Ok(row.get(0))
}

pub async fn update(
    db: &DBConnection<'_>,
    document_id: i64,
    title: &Option<String>,
    tags: &Option<Vec<String>>,
    version: &Option<i16>,
) -> Result<bool, ApiError> {
    let count: i64 = db
        .query_one(
            r#"SELECT COUNT(id) as count FROM company_document 
            WHERE id = $1"#,
            &[&document_id],
        )
        .await?
        .get("count");
    if count == 0 {
        return Err(ApiError::Error(format!(
            "Document with id '{}' does not exist",
            document_id
        )));
    }

    let mut set_clauses: Vec<String> = Vec::new();
    let mut params: Vec<&(dyn ToSql + Sync)> = Vec::new();

    if let Some(title) = &title {
        set_clauses.push(format!("title = ${}", params.len() + 1));
        params.push(title);
    }

    if let Some(version) = &version {
        set_clauses.push(format!("version = ${}", params.len() + 1));
        params.push(version);
    }

    let tags_string: String;
    if let Some(tags) = &tags {
        tags_string = helper::tag::to_string(tags);
        set_clauses.push(format!("tags = ${}", params.len() + 1));
        params.push(&tags_string)
    }

    if set_clauses.is_empty() {
        return Err(ApiError::Error(
            "Enter minimum one data to update".to_string(),
        ));
    }

    let query = format!(
        "UPDATE company_document SET {} WHERE id = ${}",
        set_clauses.join(", "),
        params.len() + 1,
    );
    params.push(&document_id);

    let val = db.execute(&query, &params).await?;

    Ok(val != 0)
}

pub async fn delete_by_id(db: &DBConnection<'_>, document_id: i64) -> Result<bool, ApiError> {
    let count: i64 = db
        .query_one(
            "SELECT COUNT(id) AS count FROM company_document WHERE id = $1",
            &[&document_id],
        )
        .await?
        .get("count");

    if count == 0 {
        return Err(ApiError::Error(format!(
            "Holiday with id '{}' does not exist",
            document_id
        )));
    }

    let val = db
        .execute(
            "DELETE FROM company_document where id = $1",
            &[&document_id],
        )
        .await?;

    Ok(val != 0)
}

pub async fn update_archive(db: &DBConnection<'_>, document_id: i64) -> Result<bool, ApiError> {
    let value = db
        .execute(
            "UPDATE company_document SET is_active = $1 WHERE id = $2",
            &[&false, &document_id],
        )
        .await?;

    Ok(value != 0)
}
```
