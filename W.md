To split the code into three files (`main.rs`, `Email_Invite.rs`, and `Email_Rest_Password.rs`), you'll need to structure the project accordingly. Here's how you can do it:

### 1. `main.rs`

This file will handle the main logic and orchestrate the worker registrations. It will also include the necessary imports for the worker modules.

```rust
mod email_invite;
mod email_reset_password;

use email_invite::create_email_invite_worker;
use email_reset_password::create_email_reset_password_worker;
use some_crate::{Monitor, TokioExecutor, WorkerBuilder, TraceLayer, RetryLayer, RetryPolicy};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    Monitor::<TokioExecutor>::new()
        .register_with_count(4, create_email_invite_worker())
        .on_event(|e| debug!("{e:?}"))
        .register_with_count(4, create_email_reset_password_worker())
        .on_event(|e| debug!("{e:?}"))
        .run_with_signal(async {
            tokio::signal::ctrl_c().await?;
            info!("Shutting down the system");
            Ok(())
        })
        .await?;
    Ok(())
}
```

### 2. `email_invite.rs`

This file will handle the worker creation logic for sending invite emails.

```rust
use some_crate::{WorkerBuilder, TraceLayer, RetryLayer, RetryPolicy};
use your_storage_crate::Storage; // Replace with the actual import for storage
use email_service;

pub fn create_email_invite_worker() -> impl Fn() -> Worker {
    WorkerBuilder::new("sendgrid-Email_Invite")
        .layer(TraceLayer::new())
        .layer(RetryLayer::new(RetryPolicy::retries(5)))
        .with_storage(Storage::pg1().clone()) // Replace with your actual storage
        .build_fn(email_service::send_invite_email)
}
```

### 3. `email_reset_password.rs`

This file will handle the worker creation logic for sending reset password emails.

```rust
use some_crate::{WorkerBuilder, TraceLayer, RetryLayer, RetryPolicy};
use your_storage_crate::Storage; // Replace with the actual import for storage
use email_service;

pub fn create_email_reset_password_worker() -> impl Fn() -> Worker {
    WorkerBuilder::new("sendgrid-Email_Rest_Password")
        .layer(TraceLayer::new())
        .layer(RetryLayer::new(RetryPolicy::retries(5)))
        .with_storage(Storage::pg2().clone()) // Replace with your actual storage
        .build_fn(email_service::send_reset_email)
}
```

### Summary

- **`main.rs`**: Contains the main application logic, registering workers and handling shutdown.
- **`email_invite.rs`**: Defines the worker for handling "Email Invite" jobs.
- **`email_reset_password.rs`**: Defines the worker for handling "Reset Password" jobs.

Make sure you adjust the imports to match your actual dependencies and project structure. This setup keeps your code modular and easier to maintain.
