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



To extend the example to include a database context, we'll use **PostgreSQL** with the **SQLx** crate for asynchronous database interactions. This example will cover setting up the database, defining the necessary data models, and integrating the database with the GraphQL API using Juniper and Axum.

### 1. Setting Up the Project

Update the `Cargo.toml` to include the necessary dependencies:

```toml
[dependencies]
axum = "0.6"
juniper = "0.15"
tokio = { version = "1", features = ["full"] }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
tower = "0.4"
sqlx = { version = "0.6", features = ["postgres", "runtime-tokio-native-tls"] }
dotenv = "0.15"
```

Make sure you have a PostgreSQL database running and create a `.env` file in the root of your project with the following content:

```
DATABASE_URL=postgres://user:password@localhost/db_name
```

Replace `user`, `password`, and `db_name` with your PostgreSQL credentials and database name.

### 2. Defining Data Models

Create a file named `models.rs`:

```rust
use serde::{Deserialize, Serialize};
use sqlx::FromRow;

#[derive(FromRow, Serialize, Deserialize, Clone)]
pub struct User {
    pub id: i32,
    pub name: String,
}
```

### 3. Database Interactions

Create a file named `db.rs` for database operations:

```rust
use sqlx::{PgPool, Result};
use crate::models::User;

pub async fn get_users(pool: &PgPool) -> Result<Vec<User>> {
    let users = sqlx::query_as!(User, "SELECT id, name FROM users")
        .fetch_all(pool)
        .await?;
    Ok(users)
}

pub async fn get_user_by_id(pool: &PgPool, user_id: i32) -> Result<Option<User>> {
    let user = sqlx::query_as!(User, "SELECT id, name FROM users WHERE id = $1", user_id)
        .fetch_optional(pool)
        .await?;
    Ok(user)
}

pub async fn create_user(pool: &PgPool, name: String) -> Result<User> {
    let user = sqlx::query_as!(User, "INSERT INTO users (name) VALUES ($1) RETURNING id, name", name)
        .fetch_one(pool)
        .await?;
    Ok(user)
}
```

### 4. GraphQL Schema with Database Context

Update the `schema.rs` file to integrate with the database:

```rust
use juniper::{graphql_object, FieldResult, RootNode};
use crate::{db, models::User};
use sqlx::PgPool;
use std::sync::Arc;

pub struct QueryRoot;

pub struct MutationRoot;

#[graphql_object(context = Arc<PgPool>)]
impl QueryRoot {
    async fn api_version() -> &str {
        "1.0"
    }

    async fn users(context: &Arc<PgPool>) -> FieldResult<Vec<User>> {
        let users = db::get_users(context).await?;
        Ok(users)
    }

    async fn user(context: &Arc<PgPool>, id: i32) -> FieldResult<User> {
        let user = db::get_user_by_id(context, id).await?;
        match user {
            Some(u) => Ok(u),
            None => Err("User not found".into()),
        }
    }
}

#[graphql_object(context = Arc<PgPool>)]
impl MutationRoot {
    async fn create_user(context: &Arc<PgPool>, name: String) -> FieldResult<User> {
        let user = db::create_user(context, name).await?;
        Ok(user)
    }
}

pub type Schema = RootNode<'static, QueryRoot, MutationRoot>;

pub fn create_schema() -> Schema {
    Schema::new(QueryRoot {}, MutationRoot {})
}
```

### 5. Setting Up Axum with Database Pool

Update the `main.rs` file to include the database pool:

```rust
use axum::{
    extract::{Extension, Json},
    response::Html,
    routing::{get, post},
    Router,
};
use dotenv::dotenv;
use sqlx::PgPool;
use std::sync::Arc;
use tokio::sync::Mutex;
use tower::ServiceBuilder;

mod db;
mod models;
mod schema;

use schema::{create_schema, Schema};

async fn graphql_handler(
    schema: Extension<Arc<Schema>>,
    pool: Extension<Arc<PgPool>>,
    request: Json<juniper::http::GraphQLRequest>,
) -> Json<juniper::http::GraphQLResponse> {
    let ctx = pool.clone();
    let response = request.execute_with_context(&schema, &ctx).await;
    Json(response)
}

async fn graphiql() -> Html<String> {
    Html(juniper::http::graphiql::graphiql_source("/graphql", None))
}

#[tokio::main]
async fn main() {
    dotenv().ok();

    let database_url = std::env::var("DATABASE_URL").expect("DATABASE_URL must be set");
    let pool = PgPool::connect(&database_url).await.unwrap();
    let schema = Arc::new(create_schema());

    let app = Router::new()
        .route("/graphql", post(graphql_handler))
        .route("/graphiql", get(graphiql))
        .layer(ServiceBuilder::new().layer(Extension(Arc::new(pool))))
        .layer(ServiceBuilder::new().layer(Extension(schema)));

    println!("GraphiQL IDE: http://localhost:3000/graphiql");

    axum::Server::bind(&"0.0.0.0:3000".parse().unwrap())
        .serve(app.into_make_service())
        .await
        .unwrap();
}
```

### 6. Setting Up the Database

Create a table for the `User` model in your PostgreSQL database:

```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL
);
```

### 7. Running the Application

To run the application, use the following command:

```sh
cargo run
```

### 8. Query and Mutation Examples

Use the GraphiQL interface at `http://localhost:3000/graphiql` to run queries and mutations.

#### Query Example

```graphql
{
  apiVersion
  users {
    id
    name
  }
  user(id: 1) {
    id
    name
  }
}
```

#### Mutation Example

```graphql
mutation {
  createUser(name: "Charlie") {
    id
    name
  }
}
```

### Explanation

- **Database Connection**: We use SQLx to manage the database connection pool and perform asynchronous operations.
- **Context in GraphQL**: The database pool is passed as a context to GraphQL resolvers, allowing them to access the database.
- **Data Models**: The `User` struct is used to represent users in both the database and GraphQL schema.

This example demonstrates a complete setup of a GraphQL API using Juniper, Axum, and PostgreSQL, including both query and mutation operations with database interaction.
