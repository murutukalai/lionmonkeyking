```rust
use lettre::{Transport, SmtpTransportBuilder};

async fn send_mail(to: &str, subject: &str, body: &str) -> Result<(), lettre::smtp::error::SendError> {
    let email = lettre::Message::builder()
        .from("your_email@example.com")
        .to(to)
        .subject(subject)
        .body(body)?
        .build()?;

    let smtp_builder = SmtpTransportBuilder::new("smtp.example.com")
        .port(587)
        .username("your_username")
        .password("your_password")?
        .authentication_mechanism(lettre::smtp::authentication::Login);

    let transport = smtp_builder.build();

    transport.send(&email).await
}

async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let to_email = "recipient@example.com";
    let subject = "Test email from Rust";
    let body = "This is a test email sent using ureq and lettre.";

    send_mail(to_email, subject, body).await?;

    println!("Email sent successfully!");

    Ok(())
}

```
https://docs.rs/axum-client-ip/latest/axum_client_ip/
