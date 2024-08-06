To incorporate a database into your GraphQL server with Juniper and Rocket in Rust, you can pass a database connection from Rocket's `State` to your Juniper context. Here’s how you can extend the previous example to include a simple database connection using `sqlx` as an example.

### 1. **Set Up Dependencies**

Add `sqlx` to your `Cargo.toml` to interact with a database. For this example, let's assume you are using PostgreSQL:

```toml
[dependencies]
juniper = "0.15"
juniper_rocket = "0.15"
rocket = "0.5"
tokio = { version = "1", features = ["full"] }
futures = "0.3"
sqlx = { version = "0.6", features = ["postgres", "runtime-async-std"] }
dotenv = "0.15"
```

### 2. **Set Up Database Connection**

Create a `.env` file at the root of your project to hold your database connection string:

```plaintext
DATABASE_URL=postgres://username:password@localhost/database_name
```

Create a new file `src/db.rs` to handle database connection pooling and querying:

```rust
use sqlx::PgPool;

pub struct Database {
    pool: PgPool,
}

impl Database {
    pub async fn new(database_url: &str) -> Result<Self, sqlx::Error> {
        let pool = PgPool::connect(database_url).await?;
        Ok(Self { pool })
    }

    pub async fn get_message(&self) -> Result<String, sqlx::Error> {
        // Example query
        let row = sqlx::query!("SELECT message FROM messages LIMIT 1")
            .fetch_one(&self.pool)
            .await?;
        Ok(row.message)
    }

    pub async fn set_message(&self, new_message: &str) -> Result<(), sqlx::Error> {
        // Example update
        sqlx::query!("UPDATE messages SET message = $1", new_message)
            .execute(&self.pool)
            .await?;
        Ok(())
    }
}
```

### 3. **Update the GraphQL Schema**

Modify `src/schema.rs` to use the database connection in the context:

```rust
use juniper::{EmptyMutation, EmptySubscription, FieldResult, RootNode, Context as JuniperContext};
use crate::db::Database;

pub struct Context {
    pub db: Database,
}

impl JuniperContext for Context {}

pub struct Query;

#[juniper::graphql_object(Context = Context)]
impl Query {
    async fn hello(context: &Context) -> FieldResult<String> {
        context.db.get_message().await.map_err(Into::into)
    }
}

pub struct Mutation;

#[juniper::graphql_object(Context = Context)]
impl Mutation {
    async fn set_message(context: &Context, new_message: String) -> FieldResult<String> {
        context.db.set_message(&new_message).await.map_err(Into::into)?;
        Ok(new_message)
    }
}

pub struct Subscription;

#[juniper::graphql_subscription(Context = Context)]
impl Subscription {
    // Example subscription placeholder
    async fn message_subscribed(&self, context: &Context) -> impl futures::Stream<Item = String> {
        futures::stream::iter(vec!["Hello", "World"].into_iter().map(|s| s.to_string()))
    }
}

pub type Schema = RootNode<'static, Query, Mutation, Subscription>;

pub fn create_schema() -> Schema {
    Schema::new(Query, Mutation, Subscription)
}
```

### 4. **Update Rocket Setup**

Modify `src/main.rs` to initialize the database and pass it to the GraphQL context:

```rust
#[macro_use] extern crate rocket;
use rocket::State;
use rocket::tokio;
use juniper_rocket::{GraphQLRequest, GraphQLResponse};
use dotenv::dotenv;
use std::env;

mod schema;
mod db;

#[get("/graphql")]
fn graphql_index() -> &'static str {
    "GraphQL endpoint"
}

#[post("/graphql", data = "<request>")]
async fn graphql_handler(
    request: GraphQLRequest,
    schema: &State<schema::Schema>,
    db: &State<db::Database>,
) -> GraphQLResponse {
    let context = schema::Context {
        db: db.clone(),
    };
    let res = juniper::execute_sync(
        &request.query,
        None,
        schema,
        &context,
        &(),
    )
    .await
    .unwrap();
    GraphQLResponse::from(res)
}

#[rocket::main]
async fn main() -> Result<(), rocket::Error> {
    dotenv().ok();
    let database_url = env::var("DATABASE_URL").expect("DATABASE_URL must be set");
    let db = db::Database::new(&database_url).await.expect("Failed to connect to database");
    let schema = schema::create_schema();
    
    rocket::build()
        .manage(schema)
        .manage(db)
        .mount("/", routes![graphql_index, graphql_handler])
        .launch()
        .await
}
```

### Summary

In this setup:

- **Database Connection**: A `Database` struct manages the connection pool and provides methods to interact with the database.
- **Context**: The GraphQL `Context` now includes a `Database` instance.
- **Schema**: The schema's resolvers use the `Database` instance to perform queries and mutations.
- **Rocket**: The Rocket application initializes the database connection, passes it to the GraphQL context, and sets up routes for GraphQL.

This approach ensures that your database connection is efficiently managed and accessible within your GraphQL resolvers.
