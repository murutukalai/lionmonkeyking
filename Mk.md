auth 
```rust
// Api-demo

use std::collections::HashMap;

use anyhow::Result;
use tinyjson::JsonValue;

struct DittoConfig {
    ditto_app_id: String,
    ditto_client_id: String,
    ditto_api_key: String,
}

fn main() -> Result<()> {
    let config = DittoConfig {
        ditto_app_id: "fe60a4fb-95b3-488e-9a98-5e58d2b7b6e2".to_string(),
        ditto_client_id: "NzE2ZDkwMjI0YjI3NDIyNw==".to_string(),
        ditto_api_key: "oDLkCktgZ4tlf9zS1wh8WDAjuM9sK7mnuffkY7sQHatn8dlWjUElQ6r3LSN8".to_string(),
    };

    let collection = "companyaccess";
    let query = "apiKey == '1963211ac52d4b43844e8179cf5b7b50'";

    // let request = r#"{"collection":"companyaccess", "query": "apiKey == '1963211ac52d4b43844e8179cf5b7b50'"}"#;
    let request = format!(r#"{{"collection":"{collection}", "query": "{query}"}}"#);

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
    .body(attohttpc::body::Text(request))
    .send()?;

    let value: JsonValue = return_value.text()?.parse()?;
    let obj: &HashMap<_, _> = value.get().unwrap();
    let val = obj.get("documents").unwrap();
    println!("{:#?}", val.format().);
    Ok(())
}
```

auth
```rust
use anyhow::Result;
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::collections::HashMap;

pub struct DittoConfig {
    pub ditto_app_id: String,
    pub ditto_client_id: String,
    pub ditto_api_key: String,
}

#[derive(Debug, Serialize, Clone)]
struct IDittoPermission {
    everything: bool,
    queries_by_collection: HashMap<String, Vec<String>>,
}

#[derive(Debug, Serialize, Clone)]
struct Permission {
    read: IDittoPermission,
    write: IDittoPermission,
}

#[derive(Debug, Serialize)]
pub struct DittoAuthResponse {
    pub authentication: bool,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub expiration_seconds: Option<i64>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub user_id: Option<String>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub permission: Option<Permission>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub user_info: Option<String>,
}

#[derive(Debug, Deserialize, Clone)]
struct CompanyDocId {
    #[serde(rename(deserialize = "companyId"))]
    company_id: String,
    #[serde(rename(deserialize = "docId"))]
    doc_id: String,
}

#[derive(Debug, Deserialize, Clone)]
struct IDittoFindDoc {
    documents: Vec<Document>,
    #[serde(rename(deserialize = "txnId"))]
    txn_id: i64,
}

#[derive(Debug, Deserialize, Clone)]
struct Document {
    #[serde(rename(deserialize = "id"))]
    id: CompanyDocId,
    fields: Fields,
}

#[derive(Debug, Deserialize, Clone)]
struct Fields {
    #[serde(rename(deserialize = "apiKey"))]
    api_key: String,
    #[serde(rename(deserialize = "authId"))]
    auth_id: String,
    #[serde(rename(deserialize = "type"))]
    field_type: String,
}
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
    params: HashMap<String, Vec<String>>,
) -> Result<IDittoFindDoc> {
    let request = json!({
        "collection": collection,
        "query": query,
        "args": params,
    });

    let return_value = attohttpc::post(format!(
        "https://{}.cloud.ditto.live/api/v4/store/find",
        ditto_config.ditto_app_id
    ))
    .header("Accept", "application/json")
    .header("Content-Type", "application/json")
    .header("X-DITTO-CLIENT-ID", ditto_config.ditto_client_id.as_str())
    .header(
        "Authorization",
        format!("Bearer {}", ditto_config.ditto_api_key).as_str(),
    )
    .json(&request)?
    .send()?;

    println!("{:#?}", return_value);
    Ok(return_value.json()?)
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

    let object = ditto_base_find(
        ditto_config,
        "companyaccess",
        &format!("apiKey == '{}'", api_key),
        HashMap::new(),
    )
    .await;

    match object {
        Ok(object) => {
            let user_id = object
                .documents
                .first()
                .map(|field| field.fields.auth_id.to_owned());
            let company_id = if let Some(com_id) = object
                .documents
                .first()
                .map(|ids| ids.id.company_id.to_owned())
            {
                com_id
            } else {
                "".to_string()
            };
            let access_id = if let Some(com_id) = object
                .documents
                .first()
                .map(|field| field.fields.auth_id.to_owned())
            {
                com_id
            } else {
                "".to_string()
            };

            let mut read: HashMap<String, Vec<String>> = HashMap::new();
            let mut write: HashMap<String, Vec<String>> = HashMap::new();

            let comp_queries = vec![format!("_id.companyId == '{}'", company_id)];
            read.insert("heartbeat".to_string(), vec!["true".to_string()]);
            read.insert("heartbeatping".to_string(), comp_queries.clone());
            write.insert("heartbeatping".to_string(), comp_queries.clone());

            // Company
            read.insert(
                "company".to_string(),
                vec![format!("_id.docId == '{}'", company_id)],
            );

            // Company access
            read.insert(
                "companyaccess".to_string(),
                vec![format!("_id.docId == '{}'", access_id)],
            );

            let read_cols = vec![
                "applicationsetting",
                "weborderwidget",
                "product",
                "category",
                "productattribute",
                "activeorder",
                "activepayment",
                "blackboxrequest",
                "ordersetting",
                "bundle",
                "giftcard",
                "giftcardusage",
                "translator",
            ];

            for col in read_cols {
                read.insert(col.to_string(), comp_queries.clone());
            }

            let write_cols = vec![
                "activeorder",
                "activepayment",
                "blackboxrequest",
                "giftcardusage",
                "orderhistoryinfo",
            ];

            for col in write_cols {
                write.insert(col.to_string(), comp_queries.clone());
            }

            let expired_on = 1;
            let expiration_seconds = Some(expired_on * 24 * 60 * 60);

            Ok(DittoAuthResponse {
                authentication: true,
                expiration_seconds,
                user_id: Some(access_id.to_string()),
                permission: Some(Permission {
                    read: IDittoPermission {
                        everything: false,
                        queries_by_collection: read,
                    },
                    write: IDittoPermission {
                        everything: false,
                        queries_by_collection: write,
                    },
                }),
                user_info: None,
            })
        }
        Err(err) => Ok(DittoAuthResponse {
            authentication: false,
            expiration_seconds: None,
            user_id: None,
            permission: None,
            user_info: Some(err.to_string()),
        }),
    }
}
```
