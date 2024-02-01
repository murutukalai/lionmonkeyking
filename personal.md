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


```
INSERT INTO subscription (email, ip_address, status)
VALUES
    ('subscriber1@email.com', '192.168.11.11', 'Active'),
    ('subscriber2@email.com', '192.168.12.12', 'Inactive'),
    ('subscriber3@email.com', '192.168.13.13', 'Active'),
    ('subscriber4@email.com', '192.168.14.14', 'Inactive'),
    ('subscriber5@email.com', '192.168.15.15', 'Active'),
    ('subscriber6@email.com', '192.168.16.16', 'Inactive'),
    ('subscriber7@email.com', '192.168.17.17', 'Active'),
    ('subscriber8@email.com', '192.168.18.18', 'Inactive'),
    ('subscriber9@email.com', '192.168.19.19', 'Active'),
    ('subscriber10@email.com', '192.168.20.20', 'Inactive');

INSERT INTO contact (email, message, ip_address, name, phone_no, status)
VALUES
    ('john.doe@email.com', 'Inquiry about services', '192.168.1.1', 'John Doe', '1234567890', 'Pending'),
    ('jane.smith@email.com', 'Product support', '192.168.2.2', 'Jane Smith', NULL, 'Completed'),
    ('alex@email.com', 'General question', '192.168.3.3', 'Alex Johnson', '9876543210', 'Pending'),
    ('emma@email.com', 'Billing inquiry', '192.168.4.4', 'Emma Williams', NULL, 'In Progress'),
    ('mike@email.com', 'Technical issue', '192.168.5.5', 'Mike Davis', '5556667777', 'Completed'),
    ('lisa@email.com', 'Service feedback', '192.168.6.6', 'Lisa Miller', '1112223333', 'Pending'),
    ('david@email.com', 'Order status', '192.168.7.7', 'David Brown', '9998887777', 'In Progress'),
    ('sara@email.com', 'Cancellation request', '192.168.8.8', 'Sara White', '1231231234', 'Pending'),
    ('chris@email.com', 'Product return', '192.168.9.9', 'Chris Taylor', '3332221111', 'Completed'),
    ('olivia@email.com', 'Subscription renewal', '192.168.10.10', 'Olivia Smith', NULL, 'Pending');

```
