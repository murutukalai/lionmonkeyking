```
#[derive(TemplateOnce)]
#[template(path = "pages/common/400.stpl")]
pub struct PageNotFound {
    page_title: String,
}

pub async fn handler_404() -> impl IntoResponse {
    let ctx = PageNotFound {
        page_title: "Roles".to_string(),
    };

    Html(ctx.render_once().unwrap())
}

.fallback(web::common::mkj::handler_404)

```
