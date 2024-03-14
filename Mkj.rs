#[derive(Debug, PartialEq)]
struct MyStruct {
    id: u32,
    name: String,
}

fn main() {
    let vec_of_structs = vec![
        MyStruct { id: 1, name: String::from("Alice") },
        MyStruct { id: 2, name: String::from("Bob") },
        MyStruct { id: 3, name: String::from("Charlie") },
    ];

    let search_id = 2;
    if let Some(found_struct) = vec_of_structs.iter().find(|s| s.id == search_id) {
        println!("Found struct: {:?}", found_struct);
    } else {
        println!("Struct not found");
    }
}

use std::collections::HashSet;

fn main() {
    let hash_set: HashSet<i32> = vec![1, 2, 3, 4, 5].into_iter().collect();
    let vec: Vec<i32> = vec![3, 4, 5, 6, 7];

    let mut union_set = hash_set.clone();
    for &element in &vec {
        union_set.insert(element);
    }

    println!("{:?}", union_set);
}

```
use std::collections::HashSet;

fn main() {
    let set1: HashSet<i32> = [1, 2, 3, 4, 5].iter().cloned().collect();
    let set2: HashSet<i32> = [3, 4, 5, 6, 7].iter().cloned().collect();

    let union_set: HashSet<&i32> = set1.union(&set2).collect();

    println!("{:?}", union_set);
}


use core::fmt::{self, Display};

use serde_derive::Deserialize;

#[derive(Debug, Deserialize)]
struct ApiErrorResponse {
    errors: Vec<Error>,
}

#[derive(Debug, Deserialize)]
#[serde(from = "ApiErrorResponse")]
struct Error {
    code: i64,
    text: String,
}

impl From<ApiErrorResponse> for Error {
    fn from(response: ApiErrorResponse) -> Self {
        Self {
            code: response.errors[0].code,
            text: response.errors[0].text.to_string(),
        }
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let body = reqwest::get("https://api.betaseries.com/search/shows")
        .await?
        .json::<ApiErrorResponse>()
        .await?;

    println!("{:#?}", body.errors);

    Ok(())
}
