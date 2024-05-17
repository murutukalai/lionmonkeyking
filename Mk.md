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
