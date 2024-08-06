To set up a GraphQL server with Juniper and Axum in Rust, you need to integrate Axum's HTTP server with Juniper's GraphQL functionality. Axum is an asynchronous web framework, while Juniper is a library for creating GraphQL APIs. Here's how you can do it:

### 1. **Add Dependencies**

First, add the necessary dependencies to your `Cargo.toml` file:

```toml
[dependencies]
axum = "0.6"
juniper = "0.15"
tokio = { version = "1", features = ["full"] }
tokio-postgres = "0.7"
deadpool-postgres = "0.9"
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
```

### 2. **Define the GraphQL Schema**

Define your GraphQL schema using Juniper. Here, we define a simple schema with a query root.

```rust
use juniper::{EmptyMutation, RootNode};

pub struct QueryRoot;

#[juniper::object]
impl QueryRoot {
    fn api_version() -> &str {
        "1.0"
    }
}

pub type Schema = RootNode<'static, QueryRoot, EmptyMutation<()>>;
```

### 3. **Create the Context**

The context will hold the state needed for your resolvers, such as the database connection pool.

```rust
use deadpool_postgres::{Client, Pool};
use std::sync::Arc;

pub struct Context {
    pub db_pool: Arc<Pool>,
}

impl juniper::Context for Context {}
```

### 4. **Set Up Database Connection and Server with Axum**

```rust
use axum::{
    extract::Extension,
    routing::post,
    response::IntoResponse,
    Router,
};
use deadpool_postgres::{Config, Pool};
use juniper::http::GraphQLRequest;
use std::sync::Arc;
use tokio_postgres::NoTls;
use tower::ServiceBuilder;
use axum::http::StatusCode;

async fn graphql_handler(
    schema: Extension<Arc<Schema>>,
    context: Extension<Arc<Context>>,
    req: GraphQLRequest,
) -> impl IntoResponse {
    let res = tokio::task::spawn_blocking(move || {
        let res = req.execute_sync(&schema, &context);
        serde_json::to_string(&res).unwrap()
    })
    .await
    .expect("Failed to execute GraphQL query");
    
    (StatusCode::OK, res)
}

#[tokio::main]
async fn main() {
    // Setup the database pool
    let mut cfg = Config::new();
    cfg.host = Some("localhost".to_string());
    cfg.dbname = Some("mydatabase".to_string());
    cfg.user = Some("myuser".to_string());
    cfg.password = Some("mypassword".to_string());
    let pool = cfg.create_pool(None, NoTls).unwrap();
    let context = Arc::new(Context {
        db_pool: Arc::new(pool),
    });

    // Define the Juniper schema
    let schema = Arc::new(Schema::new(QueryRoot, EmptyMutation::new()));

    // Define the Axum app
    let app = Router::new()
        .route("/graphql", post(graphql_handler))
        .layer(ServiceBuilder::new().layer(Extension(schema)).layer(Extension(context)));

    // Run the server
    axum::Server::bind(&"0.0.0.0:4000".parse().unwrap())
        .serve(app.into_make_service())
        .await
        .unwrap();
}
```

### 5. **Resolvers Implementation**

Here's an example resolver that queries the database:

```rust
impl QueryRoot {
    async fn get_user(
        &self,
        context: &Context,
        user_id: i32,
    ) -> Result<User, juniper::FieldError> {
        let client: Client = context.db_pool.get().await.map_err(|e| {
            juniper::FieldError::new(
                "Failed to get client from pool",
                graphql_value!({ "internal_error": format!("{:?}", e) }),
            )
        })?;
        let stmt = client
            .prepare("SELECT id, name FROM users WHERE id = $1")
            .await
            .map_err(|e| {
                juniper::FieldError::new(
                    "Failed to prepare statement",
                    graphql_value!({ "internal_error": format!("{:?}", e) }),
                )
            })?;
        let row = client.query_one(&stmt, &[&user_id]).await.map_err(|e| {
            juniper::FieldError::new(
                "Failed to execute query",
                graphql_value!({ "internal_error": format!("{:?}", e) }),
            )
        })?;
        Ok(User {
            id: row.get(0),
            name: row.get(1),
        })
    }
}

#[derive(juniper::GraphQLObject)]
struct User {
    id: i32,
    name: String,
}
```

### Explanation

1. **Dependencies**: The required dependencies include Axum for the web server, Juniper for GraphQL, and Deadpool for PostgreSQL connection pooling.

2. **Schema Definition**: The `Schema` and `QueryRoot` define the structure of your GraphQL API. The `api_version` field is a simple example.

3. **Context**: The `Context` struct holds the database connection pool, allowing resolvers to access it.

4. **Database Connection and Server**: The `main` function sets up the database connection pool and starts the Axum server. The `graphql_handler` function handles incoming GraphQL requests by executing them with the provided schema and context.

5. **Resolvers**: The `get_user` function shows how to access the database using the context and return a user.

This setup should give you a basic structure to build a GraphQL server with Juniper and Axum, connecting to a PostgreSQL database. You can expand this by adding more complex queries, mutations, and additional middleware as needed.


_--------------

