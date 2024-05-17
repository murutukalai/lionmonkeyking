auth 
```rust
// Api - Auth

use std::{collections::HashMap, env};

use anyhow::{Context, Result};
use serde::Deserialize;
use serde_json::json;

struct DittoConfig {
    ditto_app_id: String,
    ditto_client_id: String,
    ditto_api_key: String,
}

#[derive(Debug, Deserialize)]
struct CompanyDocId {
    #[serde(rename(deserialize = "docId"))]
    id: String,
    #[serde(rename(deserialize = "companyId"))]
    company_id: String,
}

#[derive(Debug, Deserialize)]
struct Platform {
    platforms: String,
    icon: String,
    image: String,
    info: String,
    printers: String,
    #[serde(rename(deserialize = "timeSlotId"))]
    time_slot_id: String,
    title: String,
    platform_type: String,
}

#[derive(Debug, Deserialize)]
struct SortInfo {
    #[serde(rename(deserialize = "categoryId"))]
    category_id: String,
    #[serde(rename(deserialize = "sortNo"))]
    sort_no: i16,
    #[serde(rename(deserialize = "type"))]
    sort_info_type: String,
}

#[derive(Debug, Deserialize)]
struct Fields {
    #[serde(rename(deserialize = "createdOn"))]
    created_on: i64,
    #[serde(rename(deserialize = "customTitle"))]
    custom_title: String,
    draft: String,
    #[serde(rename(deserialize = "enabledWidgets"))]
    enabled_widgets: Vec<String>,
    // extra: Vec<String>,
    icon: String,
    image: String,
    info: String,
    #[serde(rename(deserialize = "isArchive"))]
    is_archive: bool,
    #[serde(rename(deserialize = "isCashier"))]
    is_cashier: bool,
    #[serde(rename(deserialize = "isDeleted"))]
    is_deleted: bool,
    #[serde(rename(deserialize = "isGo"))]
    is_go: bool,
    #[serde(rename(deserialize = "isKiosk"))]
    is_kiosk: bool,
    #[serde(rename(deserialize = "isNewTag"))]
    is_new_tag: bool,
    #[serde(rename(deserialize = "isTableOrder"))]
    is_table_order: bool,
    #[serde(rename(deserialize = "isWebOrder"))]
    is_web_order: bool,
    #[serde(rename(deserialize = "modifiedOn"))]
    modified_on: i64,
    #[serde(rename(deserialize = "noProducts"))]
    no_products: i16,
    #[serde(rename(deserialize = "parentId"))]
    parent_id: String,
    // platforms: Vec<Platform>,
    printers: Vec<String>,
    #[serde(rename(deserialize = "sortInfo"))]
    sort_info: Vec<SortInfo>,
    #[serde(rename(deserialize = "sortNo"))]
    sort_no: i16,
    #[serde(rename(deserialize = "timeSlotId"))]
    time_slot_id: String,
    title: String,
    #[serde(rename(deserialize = "userTag"))]
    user_tag: String,
}

#[derive(Debug, Deserialize)]
struct Documents {
    documents: Vec<Document>,
    #[serde(rename(deserialize = "txnId"))]
    tnx_id: i64,
}

#[derive(Debug, Deserialize)]
struct Document {
    id: CompanyDocId,
    fields: Fields,
}

struct DittoAuthResponse {}

/*
read['heartbeat'] = ['true'];

{
    authenticate: false,
    userInfo: (err as Error).message || 'Invalid token',
}
return {
    authenticate: true,
    expirationSeconds: expiredOn * (24 * 60 * 60), // Days
    userID: authId,
    permissions: {
        read: {
            everything: false,
            queriesByCollection: perm.read,
        },
        write: {
            everything: false,
            queriesByCollection: perm.write,
        },
    },
}; */

async fn ditto_base_find(
    ditto_config: &DittoConfig,
    collection: &str,
    query: &str,
    limit: Option<i64>,
    offset: Option<i64>,
    params: HashMap<String, Vec<String>>,
) -> Result<Documents> {
    let mut request = json!({
        "collection": collection,
        "query": query,
        "args": params,
    });

    if let Some(map) = request.as_object_mut() {
        if let Some(limit) = limit {
            map.insert("limit".to_string(), json!(limit));
        }
        if let Some(offset) = offset {
            map.insert("offset".to_string(), json!(offset));
        }
    }

    let mut config = DittoConfig {
        ditto_app_id: "".to_string(),
        ditto_client_id: "".to_string(),
        ditto_api_key: "".to_string(),
    };

    config.ditto_app_id =
        env::var("DITTO_APP_ID").context("Unable to find DITTO_APP_ID in .env file")?;
    config.ditto_client_id =
        env::var("DITTO_CLIENT_ID").context("Unable to find DITTO_CLIENT_ID in .env file")?;
    config.ditto_api_key =
        env::var("DITTO_API_KEY").context("Unable to find DITTO_API_KEY in .env file")?;

    let return_value = attohttpc::post(format!(
        "https://{}.cloud.ditto.live/api/v4/store/find",
        config.ditto_app_id
    ))
    .header("Accept", "application/json")
    .header("Content-Type", "application/json")
    .header("X-DITTO-CLIENT-ID", config.ditto_client_id.as_str())
    .header(
        "Authorization",
        format!("Bearer {}", config.ditto_api_key).as_str(),
    )
    .json(&request)?
    .send()?;

    let values: Documents = return_value.json()?;
    println!("{:#?}", values);
    Ok(())
    /* Request
    const postData: IHttpJsonData = {
        collection,
        query,
        args,
    };
    if (limit && limit > 0) {
        postData.limit = limit;
    }
    if (offset && offset > 0) {
        postData.offset = offset;
    }

    const sort = {
        property: sortKey ?? 'createdOn',
        direction: isSortDec ? 'desc' : 'asc',
    };
    postData.sort = [sort];
    */

    /*
    const data = await httpJsonRequest(
        `https://${dittoInfo.dittoAppId}.cloud.ditto.live/api/v4/store/find`,
        'POST',
        postData,
        {
            'X-DITTO-CLIENT-ID': dittoInfo.dittoClientId,
            Authorization: `Bearer ${dittoInfo.dittoApiKey}`,
        },
    );

    if (data) {
        return data.documents ? data.documents as IDittoFindDoc[] : [];
    }
    */
}

pub async fn auth_weborder_ditto(
    ditto_config: &DittoConfig,
    api_key: &str,
) -> Result<DittoAuthResponse> {
    // ureq - get the object
}
```
api - demo
```rust
// Api-demo

use anyhow::Result;
use serde::Deserialize;
use serde_json::json;

struct DittoConfig {
    ditto_app_id: String,
    ditto_client_id: String,
    ditto_api_key: String,
}

#[derive(Debug, Deserialize)]
struct CompanyDocId {
    #[serde(rename(deserialize = "docId"))]
    id: String,
    #[serde(rename(deserialize = "companyId"))]
    company_id: String,
}

#[derive(Debug, Deserialize)]
struct Platform {
    platforms: String,
    icon: String,
    image: String,
    info: String,
    printers: String,
    #[serde(rename(deserialize = "timeSlotId"))]
    time_slot_id: String,
    title: String,
    platform_type: String,
}

#[derive(Debug, Deserialize)]
struct SortInfo {
    #[serde(rename(deserialize = "categoryId"))]
    category_id: String,
    #[serde(rename(deserialize = "sortNo"))]
    sort_no: i16,
    #[serde(rename(deserialize = "type"))]
    sort_info_type: String,
}

#[derive(Debug, Deserialize)]
struct Fields {
    #[serde(rename(deserialize = "createdOn"))]
    created_on: i64,
    #[serde(rename(deserialize = "customTitle"))]
    custom_title: String,
    draft: String,
    #[serde(rename(deserialize = "enabledWidgets"))]
    enabled_widgets: Vec<String>,
    // extra: Vec<String>,
    icon: String,
    image: String,
    info: String,
    #[serde(rename(deserialize = "isArchive"))]
    is_archive: bool,
    #[serde(rename(deserialize = "isCashier"))]
    is_cashier: bool,
    #[serde(rename(deserialize = "isDeleted"))]
    is_deleted: bool,
    #[serde(rename(deserialize = "isGo"))]
    is_go: bool,
    #[serde(rename(deserialize = "isKiosk"))]
    is_kiosk: bool,
    #[serde(rename(deserialize = "isNewTag"))]
    is_new_tag: bool,
    #[serde(rename(deserialize = "isTableOrder"))]
    is_table_order: bool,
    #[serde(rename(deserialize = "isWebOrder"))]
    is_web_order: bool,
    #[serde(rename(deserialize = "modifiedOn"))]
    modified_on: i64,
    #[serde(rename(deserialize = "noProducts"))]
    no_products: i16,
    #[serde(rename(deserialize = "parentId"))]
    parent_id: String,
    // platforms: Vec<Platform>,
    printers: Vec<String>,
    #[serde(rename(deserialize = "sortInfo"))]
    sort_info: Vec<SortInfo>,
    #[serde(rename(deserialize = "sortNo"))]
    sort_no: i16,
    #[serde(rename(deserialize = "timeSlotId"))]
    time_slot_id: String,
    title: String,
    #[serde(rename(deserialize = "userTag"))]
    user_tag: String,
}

#[derive(Debug, Deserialize)]
struct Documents {
    documents: Vec<Document>,
    #[serde(rename(deserialize = "txnId"))]
    tnx_id: i64,
}

#[derive(Debug, Deserialize)]
struct Document {
    id: CompanyDocId,
    fields: Fields,
}

fn main() -> Result<()> {
    let config = DittoConfig {
        ditto_app_id: "fe60a4fb-95b3-488e-9a98-5e58d2b7b6e2".to_string(),
        ditto_client_id: "NzE2ZDkwMjI0YjI3NDIyNw==".to_string(),
        ditto_api_key: "oDLkCktgZ4tlf9zS1wh8WDAjuM9sK7mnuffkY7sQHatn8dlWjUElQ6r3LSN8".to_string(),
    };

    let request = json!({
        "collection": "category",
        "query": "_id.docId == '652622aac5b55504ad9538c1'",
        "limit": 20
    });

    let return_value = attohttpc::post(format!(
        "https://{}.cloud.ditto.live/api/v4/store/find",
        config.ditto_app_id
    ))
    .header("Accept", "application/json")
    .header("Content-Type", "application/json")
    .header("X-DITTO-CLIENT-ID", config.ditto_client_id.as_str())
    .header(
        "Authorization",
        format!("Bearer {}", config.ditto_api_key).as_str(),
    )
    .json(&request)?
    .send()?;

    let values: Documents = return_value.json()?;
    println!("{:#?}", values);
    Ok(())
}
```

```rust
// Api-demo

use anyhow::Result;
use serde::Deserialize;
use serde_json::json;

struct DittoConfig {
    ditto_app_id: String,
    ditto_client_id: String,
    ditto_api_key: String,
}

#[derive(Debug, Deserialize)]
struct CompanyDocId {
    #[serde(rename(deserialize = "docId"))]
    id: String,
    #[serde(rename(deserialize = "companyId"))]
    company_id: String,
}

#[derive(Debug, Deserialize)]
struct Platform {
    platforms: String,
    icon: String,
    image: String,
    info: String,
    printers: String,
    #[serde(rename(deserialize = "timeSlotId"))]
    time_slot_id: String,
    title: String,
    platform_type: String,
}

#[derive(Debug, Deserialize)]
struct SortInfo {
    #[serde(rename(deserialize = "categoryId"))]
    category_id: String,
    #[serde(rename(deserialize = "sortNo"))]
    sort_no: i16,
    #[serde(rename(deserialize = "type"))]
    sort_info_type: String,
}

#[derive(Debug, Deserialize)]
struct Fields {
    #[serde(rename(deserialize = "createdOn"))]
    created_on: i64,
    #[serde(rename(deserialize = "customTitle"))]
    custom_title: String,
    draft: String,
    #[serde(rename(deserialize = "enabledWidgets"))]
    enabled_widgets: Vec<String>,
    // extra: Vec<String>,
    icon: String,
    image: String,
    info: String,
    #[serde(rename(deserialize = "isArchive"))]
    is_archive: bool,
    #[serde(rename(deserialize = "isCashier"))]
    is_cashier: bool,
    #[serde(rename(deserialize = "isDeleted"))]
    is_deleted: bool,
    #[serde(rename(deserialize = "isGo"))]
    is_go: bool,
    #[serde(rename(deserialize = "isKiosk"))]
    is_kiosk: bool,
    #[serde(rename(deserialize = "isNewTag"))]
    is_new_tag: bool,
    #[serde(rename(deserialize = "isTableOrder"))]
    is_table_order: bool,
    #[serde(rename(deserialize = "isWebOrder"))]
    is_web_order: bool,
    #[serde(rename(deserialize = "modifiedOn"))]
    modified_on: i64,
    #[serde(rename(deserialize = "noProducts"))]
    no_products: i16,
    #[serde(rename(deserialize = "parentId"))]
    parent_id: String,
    // platforms: Vec<Platform>,
    printers: Vec<String>,
    #[serde(rename(deserialize = "sortInfo"))]
    sort_info: Vec<SortInfo>,
    #[serde(rename(deserialize = "sortNo"))]
    sort_no: i16,
    #[serde(rename(deserialize = "timeSlotId"))]
    time_slot_id: String,
    title: String,
    #[serde(rename(deserialize = "userTag"))]
    user_tag: String,
}

#[derive(Debug, Deserialize)]
struct Documents {
    documents: Vec<Document>,
    #[serde(rename(deserialize = "txnId"))]
    tnx_id: i64,
}

#[derive(Debug, Deserialize)]
struct Document {
    id: CompanyDocId,
    fields: Fields,
}

fn main() -> Result<()> {
    let config = DittoConfig {
        ditto_app_id: "fe60a4fb-95b3-488e-9a98-5e58d2b7b6e2".to_string(),
        ditto_client_id: "NzE2ZDkwMjI0YjI3NDIyNw==".to_string(),
        ditto_api_key: "oDLkCktgZ4tlf9zS1wh8WDAjuM9sK7mnuffkY7sQHatn8dlWjUElQ6r3LSN8".to_string(),
    };

    let request = json!({
        "collection": "category",
        "query": "_id.docId == '652622aac5b55504ad9538c1'",
        "limit": 20
    });

    let return_value = ureq::post(&format!(
        "https://{}.cloud.ditto.live/api/v4/store/find",
        config.ditto_app_id
    ))
    .set("Accept", "application/json")
    .set("Content-Type", "application/json")
    .set("X-DITTO-CLIENT-ID", config.ditto_client_id.as_str())
    .set(
        "Authorization",
        format!("Bearer {}", config.ditto_api_key).as_str(),
    )
    .send_json(request)?;

    let value: Documents = return_value.into_json()?;
    println!("{:#?}", value);
    Ok(())
}
```
