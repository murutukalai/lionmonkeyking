execute
```
use tokio_postgres::{Config, NoTls};

async fn execute_sql_file(sql_file_path: &str) -> Result<(), tokio_postgres::Error> {
    // Read the SQL file contents
    let sql = tokio::fs::read_to_string(sql_file_path).await?;

    // Create a new PostgreSQL connection configuration
    let mut config = Config::new();
    config.host("localhost"); // Replace with your PostgreSQL host
    config.user("username"); // Replace with your PostgreSQL username
    config.password("password"); // Replace with your PostgreSQL password
    config.dbname("database_name"); // Replace with your PostgreSQL database name

    // Establish a connection to the database
    let (client, connection) = config.connect(NoTls).await?;

    // Spawn a task to run the connection in the background
    tokio::spawn(async move {
        if let Err(e) = connection.await {
            eprintln!("connection error: {}", e);
        }
    });

    // Execute the SQL commands
    client.batch_execute(&sql).await?;

    println!("SQL commands executed successfully");
    Ok(())
}

#[tokio::main]
async fn main() {
    if let Err(e) = execute_sql_file("path/to/your/sql_file.sql").await {
        eprintln!("Error executing SQL file: {}", e);
    }
}
```
