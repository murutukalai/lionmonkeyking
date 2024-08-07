Here's an example of using Postgres `LISTEN` and `NOTIFY` with Rust and the `axum` web framework. We'll use the `tokio-postgres` crate for interacting with the PostgreSQL database asynchronously and `axum` for the web server.

First, add the necessary dependencies to your `Cargo.toml` file:

```toml
[dependencies]
axum = "0.6"
tokio = { version = "1", features = ["full"] }
tokio-postgres = "0.7"
futures = "0.3"
```

Next, set up the basic structure for the Rust application:

1. Create a listener function to listen for PostgreSQL notifications.
2. Set up the `axum` web server.
3. Integrate the listener with the web server.

Here is a complete example:

```rust
use axum::{
    routing::get,
    response::Html,
    Router,
};
use tokio::sync::broadcast;
use tokio_postgres::{NoTls, Error};
use futures::stream::StreamExt;
use std::sync::Arc;
use tokio::sync::Mutex;

#[tokio::main]
async fn main() {
    // Set up the PostgreSQL connection
    let (client, connection) =
        tokio_postgres::connect("host=localhost user=postgres password=yourpassword dbname=yourdb", NoTls)
            .await
            .expect("Failed to connect to the database");

    // Spawn a task to manage the connection
    tokio::spawn(async move {
        if let Err(e) = connection.await {
            eprintln!("Connection error: {}", e);
        }
    });

    // Create a broadcast channel for sending notifications to the web server
    let (tx, _) = broadcast::channel(100);

    // Clone the sender to be used in the listener
    let tx_clone = tx.clone();
    let client = Arc::new(Mutex::new(client));
    let client_clone = client.clone();

    // Spawn a task to listen for notifications
    tokio::spawn(async move {
        listen_for_notifications(client_clone, tx_clone).await.unwrap();
    });

    // Set up the web server
    let app = Router::new().route("/", get(|| async { Html("Listening for notifications...") }));

    axum::Server::bind(&"0.0.0.0:3000".parse().unwrap())
        .serve(app.into_make_service())
        .await
        .unwrap();
}

async fn listen_for_notifications(client: Arc<Mutex<tokio_postgres::Client>>, tx: broadcast::Sender<String>) -> Result<(), Error> {
    let mut client = client.lock().await;

    // Listen for notifications on the 'example_channel'
    client.batch_execute("LISTEN example_channel").await?;

    let mut notifications = client.notifications();

    // Loop to receive notifications
    while let Some(notification) = notifications.next().await {
        let notification = notification?;
        let payload = notification.payload().to_string();
        println!("Received notification: {:?}", payload);

        // Send the notification to the broadcast channel
        let _ = tx.send(payload);
    }

    Ok(())
}
```

### Explanation:

1. **Postgres Connection**: Establishes a connection to the PostgreSQL database using `tokio-postgres`.

2. **Listener Setup**: Spawns a task to listen for notifications on a specified channel (`example_channel`). When a notification is received, it's sent through a broadcast channel.

3. **Web Server Setup**: Uses `axum` to set up a basic web server that simply returns a message indicating it's listening for notifications.

4. **Notification Listener**: Defines a function that listens for notifications from PostgreSQL and sends them through the broadcast channel.

This example demonstrates the integration of PostgreSQL `LISTEN` and `NOTIFY` with a Rust web server using `axum`. To fully utilize the notifications in a web application, you could extend this example to send the notifications to connected clients via WebSockets or another real-time communication method.


_________

Sure, I'll walk you through each part of the example in more detail, focusing on the queries and their interactions with PostgreSQL.

### 1. Establishing the PostgreSQL Connection

```rust
let (client, connection) =
    tokio_postgres::connect("host=localhost user=postgres password=yourpassword dbname=yourdb", NoTls)
        .await
        .expect("Failed to connect to the database");
```

- **Purpose**: Establishes a connection to the PostgreSQL database.
- **Query**: The connection string specifies the host, user, password, and database name.
- **Result**: Returns a `client` and a `connection` object. The `client` is used for executing queries, and the `connection` manages the actual connection.

### 2. Managing the Connection

```rust
tokio::spawn(async move {
    if let Err(e) = connection.await {
        eprintln!("Connection error: {}", e);
    }
});
```

- **Purpose**: Spawns a task to handle the connection. This is necessary because the connection needs to be continuously managed in the background.
- **Query**: No direct SQL query here, just managing the connection lifecycle.
- **Result**: Ensures the connection stays alive and handles any errors that occur.

### 3. Setting Up the Listener for Notifications

```rust
async fn listen_for_notifications(client: Arc<Mutex<tokio_postgres::Client>>, tx: broadcast::Sender<String>) -> Result<(), Error> {
    let mut client = client.lock().await;

    // Listen for notifications on the 'example_channel'
    client.batch_execute("LISTEN example_channel").await?;

    let mut notifications = client.notifications();

    // Loop to receive notifications
    while let Some(notification) = notifications.next().await {
        let notification = notification?;
        let payload = notification.payload().to_string();
        println!("Received notification: {:?}", payload);

        // Send the notification to the broadcast channel
        let _ = tx.send(payload);
    }

    Ok(())
}
```

#### Step-by-Step:

1. **Locking the Client**:
   ```rust
   let mut client = client.lock().await;
   ```
   - **Purpose**: Since `client` is shared across tasks, we use a `Mutex` to ensure safe concurrent access.
   - **Query**: No SQL query here.

2. **Listen Query**:
   ```rust
   client.batch_execute("LISTEN example_channel").await?;
   ```
   - **Purpose**: Tells PostgreSQL to start listening for notifications on the `example_channel`.
   - **Query**: 
     ```sql
     LISTEN example_channel;
     ```
   - **Result**: The client is now subscribed to notifications on `example_channel`.

3. **Receiving Notifications**:
   ```rust
   let mut notifications = client.notifications();
   while let Some(notification) = notifications.next().await {
       let notification = notification?;
       let payload = notification.payload().to_string();
       println!("Received notification: {:?}", payload);

       // Send the notification to the broadcast channel
       let _ = tx.send(payload);
   }
   ```
   - **Purpose**: Creates a loop to listen for notifications from PostgreSQL.
   - **Query**: Receives notifications without an explicit SQL query. The notifications are sent by PostgreSQL when something calls `NOTIFY example_channel, 'payload';`.
   - **Result**: Each received notification is printed and sent through a broadcast channel.

### 4. Web Server Setup with Axum

```rust
let app = Router::new().route("/", get(|| async { Html("Listening for notifications...") }));
axum::Server::bind(&"0.0.0.0:3000".parse().unwrap())
    .serve(app.into_make_service())
    .await
    .unwrap();
```

- **Purpose**: Sets up a simple web server that listens on port 3000.
- **Query**: No SQL queries here.
- **Result**: The server responds with a static message indicating that it is listening for notifications.

### Detailed Queries and Their Functions

#### `LISTEN example_channel`

- **Purpose**: Subscribes the client to notifications on `example_channel`.
- **Usage**:
  ```rust
  client.batch_execute("LISTEN example_channel").await?;
  ```

#### `NOTIFY example_channel, 'payload'`

- **Purpose**: Sends a notification to `example_channel` with the payload `'payload'`.
- **Example Usage in SQL**:
  ```sql
  NOTIFY example_channel, 'payload';
  ```
- **Effect**: Any clients listening on `example_channel` receive the notification with the payload `'payload'`.

In summary, the example demonstrates how to set up a Rust web server using `axum` that listens for PostgreSQL notifications using the `LISTEN` and `NOTIFY` commands. When a notification is received, it is printed to the console and sent through a broadcast channel, which can be used to notify web clients in a more comprehensive application.



-------

To use the `LISTEN` and `NOTIFY` commands effectively, you typically need a PostgreSQL table that triggers notifications upon certain actions (e.g., inserts, updates, deletes). Here's a step-by-step guide on how to create a table and set up a trigger that notifies a channel.

### 1. Create the Table

First, create a simple table. For this example, let's create a table named `example_table`.

```sql
CREATE TABLE example_table (
    id SERIAL PRIMARY KEY,
    message TEXT NOT NULL
);
```

- **id**: A serial primary key that auto-increments.
- **message**: A text column to store some messages.

### 2. Create a Function for the Trigger

Next, create a function that will be called by the trigger. This function will send a notification to the `example_channel`.

```sql
CREATE OR REPLACE FUNCTION notify_example_channel() RETURNS trigger AS $$
BEGIN
    PERFORM pg_notify('example_channel', NEW.message);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

- **Function Name**: `notify_example_channel`
- **Purpose**: Sends a notification to `example_channel` with the `message` from the new row (`NEW.message`).

### 3. Create the Trigger

Finally, create a trigger that calls the `notify_example_channel` function after an insert operation on `example_table`.

```sql
CREATE TRIGGER example_table_notify_trigger
AFTER INSERT ON example_table
FOR EACH ROW
EXECUTE FUNCTION notify_example_channel();
```

- **Trigger Name**: `example_table_notify_trigger`
- **Timing**: `AFTER INSERT` (runs after an insert operation)
- **Table**: `example_table`
- **Trigger Action**: Calls `notify_example_channel()` for each row inserted.

### Putting It All Together

Here is the complete SQL script to create the table, function, and trigger:

```sql
-- Step 1: Create the table
CREATE TABLE example_table (
    id SERIAL PRIMARY KEY,
    message TEXT NOT NULL
);

-- Step 2: Create the function for the trigger
CREATE OR REPLACE FUNCTION notify_example_channel() RETURNS trigger AS $$
BEGIN
    PERFORM pg_notify('example_channel', NEW.message);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 3: Create the trigger
CREATE TRIGGER example_table_notify_trigger
AFTER INSERT ON example_table
FOR EACH ROW
EXECUTE FUNCTION notify_example_channel();
```

### Testing the Setup

To test the setup, insert a row into `example_table` and observe the notification:

```sql
INSERT INTO example_table (message) VALUES ('Hello, world!');
```

This insert operation will trigger the `example_table_notify_trigger`, which will call the `notify_example_channel` function, sending a notification with the message `'Hello, world!'` to `example_channel`.

In your Rust application, the `LISTEN` command subscribes to `example_channel`, so when the above insert is executed, your application will receive the notification.

### Full Rust Example

Combining this with the Rust code from before, you get a complete solution where inserting a row into the PostgreSQL table triggers a notification that your Rust server can handle.

1. **Create the table, function, and trigger in PostgreSQL using the provided SQL script.**
2. **Run the Rust application to listen for notifications.**
3. **Insert data into `example_table` to trigger notifications.**

By following these steps, you set up an end-to-end system where database changes in PostgreSQL can trigger real-time notifications handled by a Rust web server using `axum`.
______________


Sure, let's adapt the previous example to use the `sqlx` library for interacting with PostgreSQL. The `sqlx` library provides async, compile-time checked SQL queries, which can be more efficient and safer.

First, add the necessary dependencies to your `Cargo.toml` file:

```toml
[dependencies]
axum = "0.6"
tokio = { version = "1", features = ["full"] }
sqlx = { version = "0.6", features = ["postgres", "runtime-tokio-rustls"] }
futures = "0.3"
```

Next, set up the Rust application using `sqlx` for the database connection and notification handling.

### Rust Code with sqlx

Here's the complete example using `sqlx`:

```rust
use axum::{
    routing::get,
    response::Html,
    Router,
};
use tokio::sync::broadcast;
use sqlx::{PgPool, Postgres, Executor};
use futures::stream::StreamExt;
use std::sync::Arc;
use tokio::sync::Mutex;

#[tokio::main]
async fn main() -> Result<(), sqlx::Error> {
    // Set up the PostgreSQL connection pool
    let pool = PgPool::connect("postgres://postgres:yourpassword@localhost/yourdb").await?;

    // Create the broadcast channel for sending notifications
    let (tx, _) = broadcast::channel(100);
    let tx_clone = tx.clone();

    // Spawn a task to listen for notifications
    let pool_clone = pool.clone();
    tokio::spawn(async move {
        listen_for_notifications(pool_clone, tx_clone).await.unwrap();
    });

    // Set up the web server
    let app = Router::new().route("/", get(|| async { Html("Listening for notifications...") }));

    axum::Server::bind(&"0.0.0.0:3000".parse().unwrap())
        .serve(app.into_make_service())
        .await
        .unwrap();

    Ok(())
}

async fn listen_for_notifications(pool: PgPool, tx: broadcast::Sender<String>) -> Result<(), sqlx::Error> {
    let mut conn = pool.acquire().await?;
    sqlx::query("LISTEN example_channel").execute(&mut conn).await?;

    let mut notifications = conn.notifications();

    while let Some(notification) = notifications.next().await {
        let notification = notification?;
        let payload = notification.payload().to_string();
        println!("Received notification: {:?}", payload);

        // Send the notification to the broadcast channel
        let _ = tx.send(payload);
    }

    Ok(())
}
```

### Explanation

#### Setting Up the Connection Pool

```rust
let pool = PgPool::connect("postgres://postgres:yourpassword@localhost/yourdb").await?;
```

- **Purpose**: Establishes a connection pool to the PostgreSQL database.
- **Parameters**:
  - `postgres://postgres:yourpassword@localhost/yourdb`: Connection string specifying the database user, password, host, and database name.

#### Listening for Notifications

```rust
async fn listen_for_notifications(pool: PgPool, tx: broadcast::Sender<String>) -> Result<(), sqlx::Error> {
    let mut conn = pool.acquire().await?;
    sqlx::query("LISTEN example_channel").execute(&mut conn).await?;

    let mut notifications = conn.notifications();

    while let Some(notification) = notifications.next().await {
        let notification = notification?;
        let payload = notification.payload().to_string();
        println!("Received notification: {:?}", payload);

        // Send the notification to the broadcast channel
        let _ = tx.send(payload);
    }

    Ok(())
}
```

- **Acquire Connection**:
  ```rust
  let mut conn = pool.acquire().await?;
  ```
  - Gets a connection from the pool.
- **Listen Query**:
  ```rust
  sqlx::query("LISTEN example_channel").execute(&mut conn).await?;
  ```
  - Subscribes to notifications on `example_channel`.
- **Receiving Notifications**:
  ```rust
  let mut notifications = conn.notifications();
  while let Some(notification) = notifications.next().await {
      let notification = notification?;
      let payload = notification.payload().to_string();
      println!("Received notification: {:?}", payload);

      // Send the notification to the broadcast channel
      let _ = tx.send(payload);
  }
  ```
  - Listens for notifications and sends them through the broadcast channel.

### Testing the Setup

After running the Rust application, you can test the notification system by inserting a row into the `example_table`:

```sql
INSERT INTO example_table (message) VALUES ('Hello, sqlx!');
```

This will trigger the notification and your Rust application should receive and print the message.

### Complete SQL Script

To set up the PostgreSQL table, function, and trigger:

```sql
-- Step 1: Create the table
CREATE TABLE example_table (
    id SERIAL PRIMARY KEY,
    message TEXT NOT NULL
);

-- Step 2: Create the function for the trigger
CREATE OR REPLACE FUNCTION notify_example_channel() RETURNS trigger AS $$
BEGIN
    PERFORM pg_notify('example_channel', NEW.message);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 3: Create the trigger
CREATE TRIGGER example_table_notify_trigger
AFTER INSERT ON example_table
FOR EACH ROW
EXECUTE FUNCTION notify_example_channel();
```

By following these steps and using the provided Rust code with `sqlx`, you can create an efficient and safe system for handling PostgreSQL notifications in your Rust web application using `axum`.
___________
In `sqlx` version 0.8.0, the notification API was changed. Let's update the example to be compatible with the latest version of `sqlx`.

### Updated Rust Code with `sqlx` 0.8.0

First, make sure your `Cargo.toml` specifies the correct version of `sqlx`:

```toml
[dependencies]
axum = "0.6"
tokio = { version = "1", features = ["full"] }
sqlx = { version = "0.8", features = ["postgres", "runtime-tokio-rustls"] }
futures = "0.3"
```

### Complete Rust Example

Here’s how you can listen for notifications with `sqlx` 0.8.0:

```rust
use axum::{
    routing::get,
    response::Html,
    Router,
};
use tokio::sync::broadcast;
use sqlx::{PgPool, Postgres, Executor};
use futures::stream::StreamExt;
use std::sync::Arc;
use tokio::sync::Mutex;

#[tokio::main]
async fn main() -> Result<(), sqlx::Error> {
    // Set up the PostgreSQL connection pool
    let pool = PgPool::connect("postgres://postgres:yourpassword@localhost/yourdb").await?;

    // Create the broadcast channel for sending notifications
    let (tx, _) = broadcast::channel(100);
    let tx_clone = tx.clone();

    // Spawn a task to listen for notifications
    let pool_clone = pool.clone();
    tokio::spawn(async move {
        listen_for_notifications(pool_clone, tx_clone).await.unwrap();
    });

    // Set up the web server
    let app = Router::new().route("/", get(|| async { Html("Listening for notifications...") }));

    axum::Server::bind(&"0.0.0.0:3000".parse().unwrap())
        .serve(app.into_make_service())
        .await
        .unwrap();

    Ok(())
}

async fn listen_for_notifications(pool: PgPool, tx: broadcast::Sender<String>) -> Result<(), sqlx::Error> {
    let mut conn = pool.acquire().await?;
    sqlx::query("LISTEN example_channel").execute(&mut conn).await?;

    let mut notification_stream = conn.listen("example_channel").await?;

    while let Some(notification) = notification_stream.next().await {
        let notification = notification?;
        let payload = notification.payload().to_string();
        println!("Received notification: {:?}", payload);

        // Send the notification to the broadcast channel
        let _ = tx.send(payload);
    }

    Ok(())
}
```

### Explanation

#### Listening for Notifications

```rust
async fn listen_for_notifications(pool: PgPool, tx: broadcast::Sender<String>) -> Result<(), sqlx::Error> {
    let mut conn = pool.acquire().await?;
    sqlx::query("LISTEN example_channel").execute(&mut conn).await?;

    let mut notification_stream = conn.listen("example_channel").await?;

    while let Some(notification) = notification_stream.next().await {
        let notification = notification?;
        let payload = notification.payload().to_string();
        println!("Received notification: {:?}", payload);

        // Send the notification to the broadcast channel
        let _ = tx.send(payload);
    }

    Ok(())
}
```

- **Acquire Connection**:
  ```rust
  let mut conn = pool.acquire().await?;
  ```
  - Gets a connection from the pool.
- **Listen Query**:
  ```rust
  sqlx::query("LISTEN example_channel").execute(&mut conn).await?;
  ```
  - Subscribes to notifications on `example_channel`.
- **Receiving Notifications**:
  ```rust
  let mut notification_stream = conn.listen("example_channel").await?;
  while let Some(notification) = notification_stream.next().await {
      let notification = notification?;
      let payload = notification.payload().to_string();
      println!("Received notification: {:?}", payload);

      // Send the notification to the broadcast channel
      let _ = tx.send(payload);
  }
  ```
  - Listens for notifications and sends them through the broadcast channel.

### Testing the Setup

After running the Rust application, you can test the notification system by inserting a row into the `example_table`:

```sql
INSERT INTO example_table (message) VALUES ('Hello, sqlx!');
```

This will trigger the notification and your Rust application should receive and print the message.

### Complete SQL Script

To set up the PostgreSQL table, function, and trigger:

```sql
-- Step 1: Create the table
CREATE TABLE example_table (
    id SERIAL PRIMARY KEY,
    message TEXT NOT NULL
);

-- Step 2: Create the function for the trigger
CREATE OR REPLACE FUNCTION notify_example_channel() RETURNS trigger AS $$
BEGIN
    PERFORM pg_notify('example_channel', NEW.message);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 3: Create the trigger
CREATE TRIGGER example_table_notify_trigger
AFTER INSERT ON example_table
FOR EACH ROW
EXECUTE FUNCTION notify_example_channel();
```

By following these steps and using the provided Rust code with `sqlx` 0.8.0, you can create an efficient and safe system for handling PostgreSQL notifications in your Rust web application using `axum`.
_____________
Let's expand on the previous example to include an Employee entity with queries, mutations, and subscriptions. We'll set up the database schema, define the GraphQL schema, and integrate everything with Axum.

### Project Structure

Here's a suggested directory structure for the project:

```
graphql_example/
├── Cargo.toml
├── src/
│   ├── db.rs
│   ├── main.rs
│   ├── schema.rs
│   ├── subscription.rs
│   └── employee.rs
```

### 1. **Cargo.toml**

Ensure the necessary dependencies are included:

```toml
[package]
name = "graphql_example"
version = "0.1.0"
edition = "2021"

[dependencies]
axum = "0.6"
juniper = "0.15"
juniper_axum = "0.6"
sqlx = { version = "0.7", features = ["sqlite", "runtime-tokio-native-tls", "macros"] }
tokio = { version = "1", features = ["full"] }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
tower = "0.4"
tower-http = { version = "0.4", features = ["trace"] }
async-std = "1.10"
futures = "0.3"
```

### 2. **Database Setup (db.rs)**

Add Employee model and relevant methods.

```rust
// src/db.rs
use sqlx::{SqlitePool, FromRow, Error};
use sqlx::sqlite::SqliteQueryAs;

#[derive(FromRow, Debug)]
pub struct Post {
    pub id: i64,
    pub title: String,
    pub content: String,
}

#[derive(FromRow, Debug)]
pub struct Employee {
    pub id: i64,
    pub name: String,
    pub position: String,
}

pub struct DB {
    pub pool: SqlitePool,
}

impl DB {
    pub async fn new(database_url: &str) -> Result<Self, Error> {
        let pool = SqlitePool::connect(database_url).await?;
        Ok(DB { pool })
    }

    pub async fn create_post(&self, title: &str, content: &str) -> Result<Post, Error> {
        let post = sqlx::query_as::<_, Post>(
            "INSERT INTO posts (title, content) VALUES (?, ?) RETURNING id, title, content"
        )
        .bind(title)
        .bind(content)
        .fetch_one(&self.pool)
        .await?;
        Ok(post)
    }

    pub async fn get_post(&self, id: i64) -> Result<Post, Error> {
        let post = sqlx::query_as::<_, Post>("SELECT * FROM posts WHERE id = ?")
            .bind(id)
            .fetch_one(&self.pool)
            .await?;
        Ok(post)
    }

    pub async fn update_post(&self, id: i64, title: &str, content: &str) -> Result<Post, Error> {
        let post = sqlx::query_as::<_, Post>(
            "UPDATE posts SET title = ?, content = ? WHERE id = ? RETURNING id, title, content"
        )
        .bind(title)
        .bind(content)
        .bind(id)
        .fetch_one(&self.pool)
        .await?;
        Ok(post)
    }

    // Employee-related methods
    pub async fn create_employee(&self, name: &str, position: &str) -> Result<Employee, Error> {
        let employee = sqlx::query_as::<_, Employee>(
            "INSERT INTO employees (name, position) VALUES (?, ?) RETURNING id, name, position"
        )
        .bind(name)
        .bind(position)
        .fetch_one(&self.pool)
        .await?;
        Ok(employee)
    }

    pub async fn get_employee(&self, id: i64) -> Result<Employee, Error> {
        let employee = sqlx::query_as::<_, Employee>("SELECT * FROM employees WHERE id = ?")
            .bind(id)
            .fetch_one(&self.pool)
            .await?;
        Ok(employee)
    }

    pub async fn update_employee(&self, id: i64, name: &str, position: &str) -> Result<Employee, Error> {
        let employee = sqlx::query_as::<_, Employee>(
            "UPDATE employees SET name = ?, position = ? WHERE id = ? RETURNING id, name, position"
        )
        .bind(name)
        .bind(position)
        .bind(id)
        .fetch_one(&self.pool)
        .await?;
        Ok(employee)
    }
}
```

### 3. **GraphQL Schema (schema.rs)**

Define the GraphQL schema for Employee entity.

```rust
// src/schema.rs
use juniper::{graphql_object, RootNode, FieldResult};
use crate::db::{DB, Post, Employee};

pub struct Context {
    pub db: DB,
}

impl juniper::Context for Context {}

pub struct Query;

#[graphql_object(context = Context)]
impl Query {
    async fn post(context: &Context, id: i64) -> FieldResult<Post> {
        let post = context.db.get_post(id).await?;
        Ok(post)
    }

    async fn employee(context: &Context, id: i64) -> FieldResult<Employee> {
        let employee = context.db.get_employee(id).await?;
        Ok(employee)
    }
}

pub struct Mutation;

#[graphql_object(context = Context)]
impl Mutation {
    async fn create_post(context: &Context, title: String, content: String) -> FieldResult<Post> {
        let post = context.db.create_post(&title, &content).await?;
        Ok(post)
    }

    async fn update_post(context: &Context, id: i64, title: String, content: String) -> FieldResult<Post> {
        let post = context.db.update_post(id, &title, &content).await?;
        Ok(post)
    }

    async fn create_employee(context: &Context, name: String, position: String) -> FieldResult<Employee> {
        let employee = context.db.create_employee(&name, &position).await?;
        Ok(employee)
    }

    async fn update_employee(context: &Context, id: i64, name: String, position: String) -> FieldResult<Employee> {
        let employee = context.db.update_employee(id, &name, &position).await?;
        Ok(employee)
    }
}

// Define the Subscription type
pub struct Subscription;

#[graphql_subscription(context = Context)]
impl Subscription {
    // Example of subscription that will need implementation
    async fn employees() -> impl juniper::futures::Stream<Item = Employee> {
        // Placeholder implementation
        juniper::futures::stream::empty()
    }
}

pub type Schema = RootNode<'static, Query, Mutation, Subscription>;

pub fn create_schema() -> Schema {
    Schema::new(Query, Mutation, Subscription)
}
```

### 4. **Axum Server Setup (main.rs)**

Set up the Axum server and define routes.

```rust
// src/main.rs
use axum::{routing::get, Router, Extension};
use std::sync::Arc;
use std::net::SocketAddr;
use crate::db::DB;
use crate::schema::{create_schema, Schema, Context};
use tower::ServiceBuilder;
use tower_http::trace::TraceLayer;
use juniper::http::GraphQLRequest;
use juniper_axum::{graphiql_handler, graphql_handler};

mod db;
mod schema;

#[tokio::main]
async fn main() {
    // Set up the database connection
    let db = DB::new("sqlite://:memory:").await.expect("Failed to create DB");
    
    // Create the GraphQL schema
    let schema = Arc::new(create_schema());

    // Build the Axum app
    let app = Router::new()
        .route("/graphql", graphql_handler(schema.clone()))
        .route("/graphiql", graphiql_handler("/graphql", None))
        .layer(Extension(Context { db }))
        .layer(ServiceBuilder::new().layer(TraceLayer::new_for_http()));

    // Define the server address
    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));
    println!("GraphiQL IDE: http://{}", addr);

    // Run the server
    axum::Server::bind(&addr)
        .serve(app.into_make_service())
        .await
        .unwrap();
}
```

### 5. **GraphQL Subscriptions (subscription.rs)**

For simplicity, this example provides a placeholder. Implementing a full subscription requires setting up WebSockets.

```rust
// src/subscription.rs
use futures::stream::Stream;
use std::pin::Pin;

#[derive(Clone)]
pub struct Subscription;

impl juniper::GraphQLType for Subscription {
    type Context = ();
    type TypeInfo = ();

    fn name(_: &Self::TypeInfo) -> Option<&str> {
        Some("Subscription")
    }
}

impl juniper::GraphQLSubscriptionType for Subscription {
    type Context = ();

    fn resolve_field(
        &self,
        info: &Self::TypeInfo,
        field: &str,
        args: &juniper::Arguments<Self::Context>,
        executor: &juniper::Executor<Self::Context>,
    ) -> juniper::FieldResult<Pin<Box<dyn Stream<Item = juniper::Value<Self::Context>> + Send>>> {
        unimplemented!("Subscription not yet implemented")
    }
}
```

### SQL Schema

Ensure your SQLite database has the necessary schema:

```sql
CREATE TABLE posts (
    id INTEGER PRIMARY KEY AUTOINCREMENT

,
    title TEXT NOT NULL,
    content TEXT NOT NULL
);

CREATE TABLE employees (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    position TEXT NOT NULL
);
```

### Running the Server

1. **Start the Database**: Ensure the SQLite database is available and the necessary tables are created.

2. **Run the Server**:

   ```sh
   cargo run
   ```

3. **Access GraphiQL**: The GraphiQL interface can be accessed at [http://localhost:3000/graphiql](http://localhost:3000/graphiql). You can run queries and mutations there.

### Example Queries

- **Create an Employee**:

  ```graphql
  mutation {
    createEmployee(name: "John Doe", position: "Software Engineer") {
      id
      name
      position
    }
  }
  ```

- **Get an Employee**:

  ```graphql
  query {
    employee(id: 1) {
      id
      name
      position
    }
  }
  ```

- **Update an Employee**:

  ```graphql
  mutation {
    updateEmployee(id: 1, name: "Jane Doe", position: "Senior Software Engineer") {
      id
      name
      position
    }
  }
  ```

### Conclusion

This example extends the previous setup to include an Employee entity with queries, mutations, and a placeholder for subscriptions. You can further expand the functionality by implementing full GraphQL subscriptions using WebSockets and adding more complex business logic as needed.
_______________

#[graphql_subscription(context = GraphqlDb)]
impl EmployeeSubscription {
    pub async fn employee(
        #[graphql(context)] db: &GraphqlDb,
        // mutation_type: Option<MutationType>,
    ) -> Pin<Box<dyn Stream<Item = Result<Option<EmployeeItem>, FieldError>> + Send>> {
        let pool = db.pool.clone().unwrap().as_ref().clone();
        let mut listener = PgListener::connect_with(&pool).await.unwrap();
        listener.listen("employee_channel").await.unwrap();
        let stream = async_stream::stream! {
            loop {
                if let Some(pg_notification) = listener.recv().await.unwrap() {
                    let payload = pg_notification.payload();
                    let payloads: Vec<&str> = if payload.is_empty() {
                        vec![]
                    } else {
                        payload.split(", ").collect()
                    };
                    let id = if payloads.is_empty() {
                        0
                    } else if let Ok(val) = payloads[0].parse::<i32>() {
                        val
                    } else {
                        0
                    };
                    yield get_by_id(&pool, id).await;
                }
            }
        };
        Box::pin(stream)
    }
}
_____
The issue you're experiencing with the stream stopping after one execution could be due to the way the `try_recv` method is used within the stream. The `try_recv` method attempts to receive a notification from the listener but returns immediately if there are no notifications available, which can cause the stream to terminate after processing a single notification.

To resolve this, you need to repeatedly check for notifications in a loop and yield them as they come in. Here's a modified version of your code:

```rust
#[graphql_subscription(context = GraphqlDb)]
impl EmployeeSubscription {
    pub async fn employee(
        #[graphql(context)] db: &GraphqlDb,
        // mutation_type: Option<MutationType>,
    ) -> Pin<Box<dyn Stream<Item = Result<Option<EmployeeItem>, FieldError>> + Send>> {
        let pool = db.pool.clone().unwrap().as_ref().clone();
        let mut listener = PgListener::connect_with(&pool).await.unwrap();
        listener.listen("employee_channel").await.unwrap();
        let stream = async_stream::stream! {
            loop {
                if let Some(pg_notification) = listener.recv().await.unwrap() {
                    let payload = pg_notification.payload();
                    let payloads: Vec<&str> = if payload.is_empty() {
                        vec![]
                    } else {
                        payload.split(", ").collect()
                    };
                    let id = if payloads.is_empty() {
                        0
                    } else if let Ok(val) = payloads[0].parse::<i32>() {
                        val
                    } else {
                        0
                    };
                    yield get_by_id(&pool, id).await;
                }
            }
        };
        Box::pin(stream)
    }
}
```

In this modified version, the `loop` ensures that the stream continues to listen for new notifications and processes them as they arrive. The `recv` method is used instead of `try_recv` to await new notifications, which will keep the stream alive and processing new notifications continuously.
