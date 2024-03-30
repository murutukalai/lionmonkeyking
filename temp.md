
```
use std::convert::Infallible;
use std::time::Duration;
use tokio_stream::StreamExt as _;
use axum::response::sse::Event;
use axum::response::Sse;
use axum::{Extension, Json};
use backend_api::hrms::employee;
use backend_api::OptionItem;
use sailfish::TemplateOnce;
use serde::Deserialize;
use futures::stream::{self, Stream};

use crate::route::rest::{convert, RestContentResponse, RestResult};
use crate::{
    route::rest::{RestAuthUser, RestCommonResponse},
    state::ExtAppState,
};
use backend_api::common::notification::{self, NotificationItem};



--------------------------------------------------------------------------------------------------




pub async fn handler_get_stat(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
) -> Sse<impl Stream<Item = Result<Event, Infallible>>> {
    let acl = user.get_acl();
    let db = app_state.db.conn().await.unwrap();

    acl.check_privilege(&db, user.id, "common", "notification", "view", None)
        .await.unwrap();

    let stats = notification::get_count_by_employee(&db, user.id).await.unwrap();

    let mut count_others: i64 = 0;
    let mut count_employee: i64 = 0;
    for stat in stats {
        if stat.notify_type == "employee" {
            count_employee = stat.count;
        } else {
            count_others += stat.count;
        }
    }

    let ctx = TemplateNotifyStatModal {
        count_employee,
        count_others,
        has_add_access: acl.has_privilege("common", "notification", "add", None),
    };

    let val = Json(RestContentResponse {
        success: true,
        error: None,
        content: Some(ctx.render_once().unwrap()),
    });

    let stream = stream::repeat_with(move || Event::default().json_data(val).unwrap())
        .map(Ok)
        .throttle(Duration::from_secs(1));

    Sse::new(stream).keep_alive(
        axum::response::sse::KeepAlive::new()
            .interval(Duration::from_secs(1))
            .text("keep-alive-text"),
    )
}



-----------------------------------------------------------------------------------------



axum-extra = "0.9.3"
tokio-stream = "0.1"
futures = "0.3.30"
```
