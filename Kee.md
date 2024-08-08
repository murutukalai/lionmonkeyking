To convert your `async-graphql` implementation to `juniper`, you need to make several changes. `juniper` doesn't support async out of the box like `async-graphql`, so the functions won't be `async`. Here’s how you can do it:

1. Define your GraphQL objects using `juniper::GraphQLObject`.
2. Implement the root queries and mutations without async functions.

Here’s the full conversion:

```rust
use juniper::{graphql_object, RootNode};

#[derive(Debug, Default)]
pub struct EmployeeQuery;
#[derive(Debug, Default)]
pub struct ContactQuery;
#[derive(Debug, Default)]
pub struct ExperienceQuery;

#[derive(Debug, Default)]
pub struct EmployeeMutation;
#[derive(Debug, Default)]
pub struct ContactMutation;
#[derive(Debug, Default)]
pub struct ExperienceMutation;

pub struct RootQuery;

#[graphql_object]
impl RootQuery {
    fn employee(&self) -> EmployeeQuery {
        EmployeeQuery::default()
    }

    fn contact(&self) -> ContactQuery {
        ContactQuery::default()
    }

    fn experience(&self) -> ExperienceQuery {
        ExperienceQuery::default()
    }
}

pub struct RootMutation;

#[graphql_object]
impl RootMutation {
    fn employee(&self) -> EmployeeMutation {
        EmployeeMutation::default()
    }

    fn contact(&self) -> ContactMutation {
        ContactMutation::default()
    }

    fn experience(&self) -> ExperienceMutation {
        ExperienceMutation::default()
    }
}

// Define your schema
pub type Schema = RootNode<'static, RootQuery, RootMutation>;

fn main() {
    // Create the schema
    let schema = Schema::new(RootQuery, RootMutation);

    // Use the schema with your GraphQL server setup
}
```

### Notes:

1. `juniper::graphql_object` macro is used to define GraphQL objects in Juniper.
2. Juniper does not natively support async functions; therefore, all the resolver functions are synchronous.
3. Ensure all necessary Juniper dependencies are added in your `Cargo.toml` file:

```toml
[dependencies]
juniper = "0.15"
juniper_codegen = "0.15"
```

This example sets up the structure to match your `async-graphql` setup but converted for use with `juniper`. You’ll need to implement the actual query and mutation logic within the respective `EmployeeQuery`, `ContactQuery`, `ExperienceQuery`, `EmployeeMutation`, `ContactMutation`, and `ExperienceMutation` structs.
___________________________________________________________________________________
To add subscription capabilities to your GraphQL API using Juniper, you need to integrate an additional layer, as Juniper itself does not directly support subscriptions out of the box. You can use libraries like `tokio` for asynchronous runtime and `tokio-tungstenite` for WebSocket support to handle real-time updates.

Here's an example of how you can set up a basic subscription mechanism in Rust using Juniper with WebSockets:

1. **Define your subscription types.**
2. **Set up WebSocket handling to push updates to clients.**

### Step 1: Define Subscription Types

First, let's define the subscription type and data structures:

```rust
use juniper::{graphql_object, FieldResult, RootNode, GraphQLObject, GraphQLSubscription, Executor};
use std::sync::Arc;
use futures::stream::Stream;
use tokio::sync::broadcast::{self, Receiver};

// Define your data structures
#[derive(Debug, Clone, GraphQLObject)]
pub struct Employee {
    pub id: i32,
    pub name: String,
    pub position: String,
}

// Dummy data for the example
fn get_dummy_employees() -> Vec<Employee> {
    vec![
        Employee { id: 1, name: "Alice".into(), position: "Engineer".into() },
        Employee { id: 2, name: "Bob".into(), position: "Manager".into() },
    ]
}

// EmployeeQuery struct with list and get_by_id functions
#[derive(Debug, Default)]
pub struct EmployeeQuery;

#[graphql_object]
impl EmployeeQuery {
    fn get_list(&self) -> FieldResult<Vec<Employee>> {
        // Fetch and return a list of employees
        Ok(get_dummy_employees())
    }

    fn get_by_id(&self, id: i32) -> FieldResult<Option<Employee>> {
        // Fetch and return an employee by ID
        Ok(get_dummy_employees().into_iter().find(|employee| employee.id == id))
    }
}

// Define the root query
pub struct RootQuery;

#[graphql_object]
impl RootQuery {
    fn employee(&self) -> EmployeeQuery {
        EmployeeQuery::default()
    }

    // Define other queries here
    // fn contact(&self) -> ContactQuery { ... }
    // fn experience(&self) -> ExperienceQuery { ... }
}

// Define the root mutation
pub struct RootMutation;

#[graphql_object]
impl RootMutation {
    fn employee(&self) -> EmployeeMutation {
        EmployeeMutation::default()
    }

    // Define other mutations here
    // fn contact(&self) -> ContactMutation { ... }
    // fn experience(&self) -> ExperienceMutation { ... }
}

// Define the subscription type
pub struct RootSubscription;

#[graphql_subscription]
impl RootSubscription {
    async fn employee_updates<'a>(
        &self,
        executor: &'a Executor<'_, '_, (), ()>,
    ) -> FieldResult<impl Stream<Item = Employee> + 'a> {
        let mut receiver = executor.context().receiver.clone();
        let stream = async_stream::stream! {
            while let Ok(employee) = receiver.recv().await {
                yield employee;
            }
        };
        Ok(stream)
    }
}

// Define your schema
pub type Schema = RootNode<'static, RootQuery, RootMutation, RootSubscription>;

#[tokio::main]
async fn main() {
    let (sender, receiver) = broadcast::channel(100);

    // Create the schema
    let schema = Schema::new(RootQuery, RootMutation, RootSubscription);

    // Set up your GraphQL server and WebSocket handling here
    // ...

    // Example: Sending updates to clients
    let employee = Employee { id: 3, name: "Charlie".into(), position: "Analyst".into() };
    sender.send(employee.clone()).unwrap();

    // Use the schema with your GraphQL server setup
}
```

### Step 2: Set Up WebSocket Handling

You'll need to integrate WebSocket handling to manage real-time updates. This can be done using `tokio` and `tokio-tungstenite`.

Here's a basic outline of how you might set up the WebSocket server:

```rust
use warp::{http::Response, Filter};
use juniper_warp::subscriptions::graphql_subscriptions;

#[tokio::main]
async fn main() {
    let (sender, receiver) = broadcast::channel(100);

    let schema = std::sync::Arc::new(Schema::new(RootQuery, RootMutation, RootSubscription));

    let graphql_filter = juniper_warp::make_graphql_filter(schema.clone(), ());

    let subscriptions_filter = graphql_subscriptions(schema, warp::any().map(move || receiver.clone()));

    let routes = warp::path("graphql")
        .and(warp::get())
        .and(graphql_filter)
        .or(warp::path("subscriptions")
            .and(warp::ws())
            .and(subscriptions_filter));

    warp::serve(routes).run(([127, 0, 0, 1], 3030)).await;
}
```

### Explanation:

1. **Data Structures**: Define the `Employee` struct and implement necessary resolvers.
2. **EmployeeQuery**: Define functions to fetch the list of employees and retrieve an employee by ID.
3. **RootQuery and RootMutation**: Define the root queries and mutations.
4. **RootSubscription**: Define the subscription type with an `employee_updates` function that streams updates.
5. **Schema**: Create a schema that includes the queries, mutations, and subscriptions.
6. **WebSocket Handling**: Use `warp` and `tokio` to set up a WebSocket server to handle GraphQL subscriptions.

This example outlines the basic setup to integrate subscriptions in Juniper using WebSockets. You'll need to fill in the details for your specific use case, such as handling different types of updates and integrating with your data source.
