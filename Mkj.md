To create a custom scalar in Juniper (for example, a `Decimal` or `UUID`), you'll define a new type that implements the `juniper::GraphQLScalarValue` trait. Below is a step-by-step guide on how to create and use a custom scalar in a Juniper-based GraphQL API using Axum.

### 1. Define the Custom Scalar

Let's create a custom scalar called `MyDecimal` that wraps around a `f64`.

```rust
use juniper::{GraphQLScalarValue, InputValue, ScalarToken, ScalarValue, Value};
use std::fmt;

#[derive(Debug, Clone)]
struct MyDecimal(f64);

impl MyDecimal {
    fn new(value: f64) -> Self {
        MyDecimal(value)
    }
}

// Implement the GraphQLScalarValue trait for MyDecimal
impl ScalarValue for MyDecimal {
    fn as_int(&self) -> Option<i32> {
        None
    }

    fn as_float(&self) -> Option<f64> {
        Some(self.0)
    }

    fn as_string(&self) -> Option<String> {
        Some(self.0.to_string())
    }

    fn as_boolean(&self) -> Option<bool> {
        None
    }

    fn as_enum(&self) -> Option<&str> {
        None
    }

    fn into_another(self) -> Result<ScalarToken<'static>, Self> {
        Err(self)
    }

    fn from_str(value: ScalarToken<'_>) -> Option<Self> {
        match value {
            ScalarToken::Float(v) => Some(MyDecimal(v)),
            _ => None,
        }
    }

    fn as_str<'a>(&'a self) -> Option<&'a str> {
        None
    }
}

impl fmt::Display for MyDecimal {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

impl<'a> From<&'a MyDecimal> for Value {
    fn from(d: &'a MyDecimal) -> Value {
        Value::scalar(d.0)
    }
}

impl<'a> From<MyDecimal> for InputValue {
    fn from(d: MyDecimal) -> InputValue {
        InputValue::scalar(d.0)
    }
}
```

### 2. Implement the Scalar GraphQL Object

In order to use `MyDecimal` in your GraphQL schema, you'll need to implement a `GraphQLScalar` for it:

```rust
use juniper::{GraphQLScalar, GraphQLObject};

#[juniper::graphql_scalar(
    with = Self,
    parse_token(ScalarToken)
)]
impl GraphQLScalar for MyDecimal {
    fn resolve(&self) -> Value {
        Value::scalar(self.0)
    }

    fn from_input_value(value: &InputValue) -> Option<MyDecimal> {
        value.as_scalar_value::<f64>().map(|&v| MyDecimal(v))
    }

    fn from_str<'a>(value: ScalarToken<'a>) -> juniper::ParseScalarResult<'a, Self> {
        if let ScalarToken::Float(v) = value {
            Ok(MyDecimal(v))
        } else {
            Err(juniper::ParseScalarError::UnexpectedToken(value))
        }
    }
}
```

### 3. Use the Custom Scalar in the GraphQL Schema

With the custom scalar defined, you can now integrate it into your GraphQL schema and use it in queries:

```rust
use axum::{
    extract::Extension,
    routing::get,
    Router,
    response::IntoResponse,
};
use std::sync::Arc;
use juniper::http::GraphQLRequest;

// Define your GraphQL context, query, and schema as before
struct Context;

impl juniper::Context for Context {}

struct Query;

#[juniper::graphql_object(Context = Context)]
impl Query {
    fn custom_decimal_value() -> MyDecimal {
        MyDecimal::new(123.456)
    }
}

type Schema = juniper::RootNode<'static, Query, juniper::EmptyMutation<Context>, juniper::EmptySubscription<Context>>;

async fn graphql_handler(
    schema: Extension<Arc<Schema>>,
    request: GraphQLRequest,
    context: Extension<Context>,
) -> impl IntoResponse {
    let response = request.execute(&schema, &context).await;
    axum::Json(response)
}

async fn graphql_playground() -> impl IntoResponse {
    axum::response::Html(juniper_rocket::playground_source("/graphql"))
}

#[tokio::main]
async fn main() {
    let schema = Arc::new(Schema::new(Query, juniper::EmptyMutation::new(), juniper::EmptySubscription::new()));

    let app = Router::new()
        .route("/graphql", get(graphql_playground).post(graphql_handler))
        .layer(Extension(schema))
        .layer(Extension(Context));

    axum::Server::bind(&"0.0.0.0:3000".parse().unwrap())
        .serve(app.into_make_service())
        .await
        .unwrap();
}
```

### 4. Query the Custom Scalar

Now you can query your GraphQL API to get the custom scalar value:

```graphql
query {
  customDecimalValue
}
```

This will return:

```json
{
  "data": {
    "customDecimalValue": 123.456
  }
}
```

### Explanation

- **ScalarValue Implementation**: The `MyDecimal` type implements `juniper::ScalarValue` to define how it should behave as a scalar in GraphQL.
- **GraphQLScalar Implementation**: The `GraphQLScalar` trait is implemented for `MyDecimal`, allowing it to be serialized/deserialized within the GraphQL schema.
- **Usage in Schema**: The custom scalar can now be used in queries or as input types wherever necessary.

This setup allows you to define and use custom scalar types in your GraphQL schema with Juniper and Axum.
