To implement the `RootSubscription` with nested `EmployeeSubscription`, `ContactSubscription`, and `ExperienceSubscription`, as well as create, update, and delete mutations, follow the steps below. We'll use `async-graphql` for GraphQL schema definition and Warp as the web server.

### 1. **Dependencies**

Ensure your `Cargo.toml` includes the necessary dependencies:

```toml
[dependencies]
async-graphql = "6.0"
async-graphql-warp = "6.0"
tokio = { version = "1.0", features = ["full"] }
futures = "0.3"
uuid = "1.0"
warp = "0.3"
```

### 2. **Data Models and Storage**

Define the data models and a simple in-memory storage mechanism.

```rust
use async_graphql::{SimpleObject, ID};
use std::sync::{Arc, Mutex};
use uuid::Uuid;

#[derive(SimpleObject, Clone)]
pub struct Employee {
    id: ID,
    name: String,
}

#[derive(SimpleObject, Clone)]
pub struct Contact {
    id: ID,
    info: String,
}

#[derive(SimpleObject, Clone)]
pub struct Experience {
    id: ID,
    details: String,
}

#[derive(Default)]
pub struct Database {
    employees: Mutex<Vec<Employee>>,
    contacts: Mutex<Vec<Contact>>,
    experiences: Mutex<Vec<Experience>>,
}

impl Database {
    pub fn new() -> Self {
        Self {
            employees: Mutex::new(vec![]),
            contacts: Mutex::new(vec![]),
            experiences: Mutex::new(vec![]),
        }
    }

    pub fn add_employee(&self, employee: Employee) {
        self.employees.lock().unwrap().push(employee);
    }

    pub fn update_employee(&self, id: &ID, name: String) -> Option<Employee> {
        let mut employees = self.employees.lock().unwrap();
        if let Some(employee) = employees.iter_mut().find(|e| &e.id == id) {
            employee.name = name;
            return Some(employee.clone());
        }
        None
    }

    pub fn delete_employee(&self, id: &ID) -> Option<Employee> {
        let mut employees = self.employees.lock().unwrap();
        if let Some(index) = employees.iter().position(|e| &e.id == id) {
            return Some(employees.remove(index));
        }
        None
    }

    pub fn add_contact(&self, contact: Contact) {
        self.contacts.lock().unwrap().push(contact);
    }

    pub fn update_contact(&self, id: &ID, info: String) -> Option<Contact> {
        let mut contacts = self.contacts.lock().unwrap();
        if let Some(contact) = contacts.iter_mut().find(|c| &c.id == id) {
            contact.info = info;
            return Some(contact.clone());
        }
        None
    }

    pub fn delete_contact(&self, id: &ID) -> Option<Contact> {
        let mut contacts = self.contacts.lock().unwrap();
        if let Some(index) = contacts.iter().position(|c| &c.id == id) {
            return Some(contacts.remove(index));
        }
        None
    }

    pub fn add_experience(&self, experience: Experience) {
        self.experiences.lock().unwrap().push(experience);
    }

    pub fn update_experience(&self, id: &ID, details: String) -> Option<Experience> {
        let mut experiences = self.experiences.lock().unwrap();
        if let Some(experience) = experiences.iter_mut().find(|e| &e.id == id) {
            experience.details = details;
            return Some(experience.clone());
        }
        None
    }

    pub fn delete_experience(&self, id: &ID) -> Option<Experience> {
        let mut experiences = self.experiences.lock().unwrap();
        if let Some(index) = experiences.iter().position(|e| &e.id == id) {
            return Some(experiences.remove(index));
        }
        None
    }
}
```

### 3. **Mutations**

Define a `MutationRoot` with create, update, and delete operations for employees, contacts, and experiences.

```rust
use async_graphql::{Schema, Object, ID, Context, FieldResult};

pub struct MutationRoot;

#[Object]
impl MutationRoot {
    async fn create_employee(&self, ctx: &Context<'_>, name: String) -> Employee {
        let db = ctx.data::<Arc<Database>>().unwrap();
        let employee = Employee {
            id: ID::from(Uuid::new_v4().to_string()),
            name,
        };
        db.add_employee(employee.clone());
        employee
    }

    async fn update_employee(&self, ctx: &Context<'_>, id: ID, name: String) -> FieldResult<Employee> {
        let db = ctx.data::<Arc<Database>>().unwrap();
        db.update_employee(&id, name).ok_or_else(|| "Employee not found".into())
    }

    async fn delete_employee(&self, ctx: &Context<'_>, id: ID) -> FieldResult<bool> {
        let db = ctx.data::<Arc<Database>>().unwrap();
        Ok(db.delete_employee(&id).is_some())
    }

    async fn create_contact(&self, ctx: &Context<'_>, info: String) -> Contact {
        let db = ctx.data::<Arc<Database>>().unwrap();
        let contact = Contact {
            id: ID::from(Uuid::new_v4().to_string()),
            info,
        };
        db.add_contact(contact.clone());
        contact
    }

    async fn update_contact(&self, ctx: &Context<'_>, id: ID, info: String) -> FieldResult<Contact> {
        let db = ctx.data::<Arc<Database>>().unwrap();
        db.update_contact(&id, info).ok_or_else(|| "Contact not found".into())
    }

    async fn delete_contact(&self, ctx: &Context<'_>, id: ID) -> FieldResult<bool> {
        let db = ctx.data::<Arc<Database>>().unwrap();
        Ok(db.delete_contact(&id).is_some())
    }

    async fn create_experience(&self, ctx: &Context<'_>, details: String) -> Experience {
        let db = ctx.data::<Arc<Database>>().unwrap();
        let experience = Experience {
            id: ID::from(Uuid::new_v4().to_string()),
            details,
        };
        db.add_experience(experience.clone());
        experience
    }

    async fn update_experience(&self, ctx: &Context<'_>, id: ID, details: String) -> FieldResult<Experience> {
        let db = ctx.data::<Arc<Database>>().unwrap();
        db.update_experience(&id, details).ok_or_else(|| "Experience not found".into())
    }

    async fn delete_experience(&self, ctx: &Context<'_>, id: ID) -> FieldResult<bool> {
        let db = ctx.data::<Arc<Database>>().unwrap();
        Ok(db.delete_experience(&id).is_some())
    }
}
```

### 4. **Subscriptions**

Define the `EmployeeSubscription`, `ContactSubscription`, and `ExperienceSubscription` with streams.

```rust
use async_graphql::{Subscription, Context};
use futures::stream::{Stream, StreamExt};
use tokio::sync::broadcast;
use std::sync::Arc;

pub struct EmployeeSubscription;

#[Subscription]
impl EmployeeSubscription {
    async fn employee_updates(&self, ctx: &Context<'_>) -> impl Stream<Item = Employee> {
        let receiver = ctx.data::<Arc<Mutex<broadcast::Receiver<Employee>>>>().unwrap().lock().unwrap().clone();
        async_stream::stream! {
            while let Ok(update) = receiver.recv().await {
                yield update;
            }
        }
    }
}

pub struct ContactSubscription;

#[Subscription]
impl ContactSubscription {
    async fn contact_updates(&self, ctx: &Context<'_>) -> impl Stream<Item = Contact> {
        let receiver = ctx.data::<Arc<Mutex<broadcast::Receiver<Contact>>>>().unwrap().lock().unwrap().clone();
        async_stream::stream! {
            while let Ok(update) = receiver.recv().await {
                yield update;
            }
        }
    }
}

pub struct ExperienceSubscription;

#[Subscription]
impl ExperienceSubscription {
    async fn experience_updates(&self, ctx: &Context<'_>) -> impl Stream<Item = Experience> {
        let receiver = ctx.data::<Arc<Mutex<broadcast::Receiver<Experience>>>>().unwrap().lock().unwrap().clone();
        async_stream::stream! {
            while let Ok(update) = receiver.recv().await {
                yield update;
            }
        }
    }
}
```

### 5. **Schema and Server Setup**

Integrate the schema and set up the server to handle subscriptions.

```rust
use async_graphql::{Schema, EmptyQuery};
use async_graphql_warp::GraphQLSubscription;
use warp::{http::Response, Filter};
use tokio::sync::broadcast;
use std::sync::{Arc, Mutex};

#[tokio::main]
async fn main() {
    // Database
    let db = Arc::new(Database::new());

    // Broadcast channels for each subscription
    let (employee_sender, _) = broadcast::channel(100);
    let (contact_sender, _) = broadcast::channel(100);
    let (experience_sender, _) = broadcast::channel(100);

    // Wrap senders in Arc and Mutex for shared ownership and thread safety
    let employee_sender = Arc::new(Mutex::new(employee_sender));
    let contact_sender = Arc::new(Mutex::new(contact_sender));
    let experience_sender = Arc::new(Mutex::new(experience_sender));

    //

 Build schema
    let schema = Schema::build(EmptyQuery, MutationRoot, RootSubscription)
        .data(db.clone())
        .data(employee_sender.clone())
        .data(contact_sender.clone())
        .data(experience_sender.clone())
        .finish();

    // Warp server
    let graphql_subscription = warp::path("subscriptions").and(GraphQLSubscription::new(schema.clone()));

    warp::serve(graphql_subscription)
        .run(([127, 0, 0, 1], 8080))
        .await;
}
```

### 6. **Testing and Usage**

- **Create Employee:**
  ```graphql
  mutation {
    createEmployee(name: "John Doe") {
      id
      name
    }
  }
  ```

- **Update Employee:**
  ```graphql
  mutation {
    updateEmployee(id: "employee-id", name: "Jane Doe") {
      id
      name
    }
  }
  ```

- **Delete Employee:**
  ```graphql
  mutation {
    deleteEmployee(id: "employee-id")
  }
  ```

- **Subscribe to Employee Updates:**
  ```graphql
  subscription {
    employee {
      employeeUpdates {
        id
        name
      }
    }
  }
  ```

### Explanation

1. **Data Models:** Define simple models for `Employee`, `Contact`, and `Experience`.
2. **Database:** In-memory data store for managing entities.
3. **Mutations:** Implement create, update, and delete operations.
4. **Subscriptions:** Allow clients to subscribe to real-time updates.
5. **Server Setup:** Warp server setup with `async-graphql` to serve GraphQL queries, mutations, and subscriptions.

This setup provides a complete implementation for managing entities with real-time updates in a Rust application using `async-graphql`. You can extend this further by adding more sophisticated logic, error handling, and data persistence mechanisms.















To implement a Rust application with Axum that separates GraphQL subscriptions, endpoints, and UI, follow these steps:

### 1. **Dependencies**

Update your `Cargo.toml` with the necessary dependencies:

```toml
[dependencies]
async-graphql = "6.0"
async-graphql-axum = "6.0"
tokio = { version = "1", features = ["full"] }
axum = "0.6"
tower = "0.4"
uuid = "1.0"
futures = "0.3"
```

### 2. **Data Models and Storage**

Define your data models and storage as previously described:

```rust
use async_graphql::{SimpleObject, ID};
use std::sync::{Arc, Mutex};
use uuid::Uuid;

#[derive(SimpleObject, Clone)]
pub struct Employee {
    id: ID,
    name: String,
}

#[derive(SimpleObject, Clone)]
pub struct Contact {
    id: ID,
    info: String,
}

#[derive(SimpleObject, Clone)]
pub struct Experience {
    id: ID,
    details: String,
}

#[derive(Default)]
pub struct Database {
    employees: Mutex<Vec<Employee>>,
    contacts: Mutex<Vec<Contact>>,
    experiences: Mutex<Vec<Experience>>,
}

impl Database {
    pub fn new() -> Self {
        Self {
            employees: Mutex::new(vec![]),
            contacts: Mutex::new(vec![]),
            experiences: Mutex::new(vec![]),
        }
    }

    pub fn add_employee(&self, employee: Employee) {
        self.employees.lock().unwrap().push(employee);
    }

    pub fn update_employee(&self, id: &ID, name: String) -> Option<Employee> {
        let mut employees = self.employees.lock().unwrap();
        if let Some(employee) = employees.iter_mut().find(|e| &e.id == id) {
            employee.name = name;
            return Some(employee.clone());
        }
        None
    }

    pub fn delete_employee(&self, id: &ID) -> Option<Employee> {
        let mut employees = self.employees.lock().unwrap();
        if let Some(index) = employees.iter().position(|e| &e.id == id) {
            return Some(employees.remove(index));
        }
        None
    }

    // Similarly define methods for contacts and experiences
}
```

### 3. **GraphQL Schema and Root Definitions**

Define your GraphQL schema, including subscriptions and mutations:

```rust
use async_graphql::{Schema, Object, Context, FieldResult, Subscription, EmptyQuery};

pub struct MutationRoot;

#[Object]
impl MutationRoot {
    async fn create_employee(&self, ctx: &Context<'_>, name: String) -> Employee {
        let db = ctx.data::<Arc<Database>>().unwrap();
        let employee = Employee {
            id: ID::from(Uuid::new_v4().to_string()),
            name,
        };
        db.add_employee(employee.clone());
        employee
    }

    async fn update_employee(&self, ctx: &Context<'_>, id: ID, name: String) -> FieldResult<Employee> {
        let db = ctx.data::<Arc<Database>>().unwrap();
        db.update_employee(&id, name).ok_or_else(|| "Employee not found".into())
    }

    async fn delete_employee(&self, ctx: &Context<'_>, id: ID) -> FieldResult<bool> {
        let db = ctx.data::<Arc<Database>>().unwrap();
        Ok(db.delete_employee(&id).is_some())
    }

    // Similarly define mutations for contacts and experiences
}

pub struct SubscriptionRoot;

#[Subscription]
impl SubscriptionRoot {
    async fn employee_updates(&self, ctx: &Context<'_>) -> impl Stream<Item = Employee> {
        let receiver = ctx.data::<Arc<Mutex<broadcast::Receiver<Employee>>>>().unwrap().lock().unwrap().clone();
        async_stream::stream! {
            while let Ok(update) = receiver.recv().await {
                yield update;
            }
        }
    }

    // Similarly define subscriptions for contacts and experiences
}
```

### 4. **Axum Router Setup**

Set up Axum with separate routing for GraphQL subscriptions, endpoints, and UI.

```rust
use axum::{routing::get, Router, Json};
use async_graphql_axum::{GraphQLRequest, GraphQLResponse};
use std::net::SocketAddr;
use axum::extract::Extension;
use tower::ServiceBuilder;
use tokio::sync::broadcast;

#[tokio::main]
async fn main() {
    let db = Arc::new(Database::new());

    let (employee_sender, _) = broadcast::channel(100);
    let (contact_sender, _) = broadcast::channel(100);
    let (experience_sender, _) = broadcast::channel(100);

    let employee_sender = Arc::new(Mutex::new(employee_sender));
    let contact_sender = Arc::new(Mutex::new(contact_sender));
    let experience_sender = Arc::new(Mutex::new(experience_sender));

    let schema = Schema::build(EmptyQuery, MutationRoot, SubscriptionRoot)
        .data(db.clone())
        .data(employee_sender.clone())
        .data(contact_sender.clone())
        .data(experience_sender.clone())
        .finish();

    let graphql_router = Router::new()
        .route("/graphql", get(move || {
            async_graphql_axum::graphql(schema.clone())
        }))
        .route("/subscriptions", get(move || {
            async_graphql_axum::graphql(schema.clone())
        }));

    let ui_router = Router::new()
        .route("/", get(|| async { "GraphQL UI" }));

    let app = Router::new()
        .nest("/api", graphql_router)
        .nest("/ui", ui_router);

    let addr = SocketAddr::from(([127, 0, 0, 1], 8080));
    println!("Listening on {}", addr);
    axum::Server::bind(&addr)
        .serve(app.into_make_service())
        .await
        .unwrap();
}
```

### 5. **UI Integration**

For the UI part, you can either serve static files or integrate a frontend framework that communicates with your GraphQL API. In this example, the `/ui` route serves a placeholder message; you can replace it with static file serving or other UI components.

### Explanation

1. **Data Models and Storage**: 
   - Models are defined and stored in an in-memory `Database`.

2. **GraphQL Schema**:
   - Define `MutationRoot` for CRUD operations and `SubscriptionRoot` for subscriptions.

3. **Axum Router**:
   - Define separate routers for GraphQL subscriptions, API endpoints, and UI.
   - Use `graphql` for handling GraphQL requests and subscriptions.

4. **Server Setup**:
   - Configure Axum to listen on a specified address and handle incoming requests.

This setup provides a clean separation of concerns, with distinct routes for API endpoints, subscriptions, and UI components, allowing for a modular and maintainable Rust application using Axum and async-graphql.
