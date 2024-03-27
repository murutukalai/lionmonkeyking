```rust
use aws_config::meta::region::RegionProviderChain;
use aws_sdk_cognitoidentityprovider::{Client, Region};
use axum::{
    extract::Query,
    http::StatusCode,
    response::{Html, IntoResponse, Redirect},
    routing::get,
    Router,
};
use serde::Deserialize;
use serde_json::Value;
use std::{env, net::SocketAddr};
use tower_cookies::{Cookie, CookieManagerLayer, Cookies};
use urlencoding::encode;

#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/", get(root))
        .route("/login", get(login))
        .route("/aws_cognito_redirect", get(aws_cognito_redirect))
        .route("/logout", get(logout))
        .layer(CookieManagerLayer::new());

    let addr = SocketAddr::from(([0, 0, 0, 0], 3000));
    axum::Server::bind(&addr)
        .serve(app.into_make_service())
        .await
        .unwrap();
}

async fn root(cookies: Cookies) -> impl IntoResponse {
    if let Some(access_token_cookie) = cookies.get("access_token") {
        let access_token = access_token_cookie.value();

        let region_provider = RegionProviderChain::first_try(Region::new("eu-west-2"));
        let shared_config = aws_config::from_env().region(region_provider).load().await;
        let config = aws_sdk_cognitoidentityprovider::config::Builder::from(&shared_config)
            .retry_config(aws_config::RetryConfig::disabled())
            .build();

        let client = Client::from_conf(config);

        let response = client
            .get_user()
            .access_token(access_token.to_string())
            .send()
            .await;

        dbg!(&response);

        match response {
            Ok(_) => {
                // Token is valid, show the private content
                let body = format!(
                    r#"<a href="/logout">Logout</a><div>This is private info you can only see when logged in."</div>"#
                );
                Html(body).into_response()
            }
            // Token is invalid so show Login link
            Err(_) => Html(r#"<a href="/login">Login</a>"#).into_response(),
        }
    } else {
        // No token provided so show Login link
        Html(r#"<a href="/login">Login</a>"#).into_response()
    }
}

async fn login() -> Redirect {
    let cognito_domain = env::var("COGNITO_DOMAIN").unwrap();
    let client_id = env::var("COGNITO_CLIENT_ID").unwrap();
    let redirect_uri = encode("http://localhost:3000/aws_cognito_redirect");

    let login_url = format!(
        "{}/login?client_id={}&response_type=code&redirect_uri={}",
        cognito_domain, client_id, redirect_uri
    );
    Redirect::permanent(&login_url)
}

#[derive(Deserialize)]
struct RedirectParams {
    code: Option<String>,
}
async fn aws_cognito_redirect(
    Query(params): Query<RedirectParams>,
    cookies: Cookies,
) -> impl IntoResponse {
    let code = if let Some(code) = params.code {
        code
    } else {
        return (StatusCode::BAD_REQUEST, "No code found in query string").into_response();
    };

    let client = reqwest::Client::new();
    let token_url = format!("{}/oauth2/token", env::var("COGNITO_DOMAIN").unwrap());
    let params = [
        ("grant_type", "authorization_code"),
        ("client_id", &env::var("COGNITO_CLIENT_ID").unwrap()),
        ("code", &code),
        ("redirect_uri", "http://localhost:3000/aws_cognito_redirect"),
    ];

    let response = client.post(token_url).form(&params).send().await;

    match response {
        Ok(res) => {
            if res.status().is_success() {
                let tokens: Value = res.json().await.unwrap();
                dbg!(&tokens);
                if let Some(access_token) = tokens.get("access_token").and_then(|t| t.as_str()) {
                    cookies.add(Cookie::new("access_token", access_token.to_string()));
                }
                (StatusCode::SEE_OTHER, [("Location", "/")]).into_response()
            } else {
                (StatusCode::BAD_REQUEST, "Failed to exchange code for token").into_response()
            }
        }
        Err(_) => (StatusCode::INTERNAL_SERVER_ERROR, "Cognito Request failed").into_response(),
    }
}

async fn logout() -> Redirect {
    let cognito_domain = env::var("COGNITO_DOMAIN").unwrap();
    let client_id = env::var("COGNITO_CLIENT_ID").unwrap();
    let logout_uri = encode("http://localhost:3000");

    let logout_url =
        format!("{cognito_domain}/logout?client_id={client_id}&logout_uri={logout_uri}");

    Redirect::permanent(&logout_url)
}

```

```
https://github.com/awslabs/aws-sdk-rust
https://docs.rs/aws-sdk-cognitoidentityprovider/latest/aws_sdk_cognitoidentityprovider/
https://github.com/MoonKraken/youtube/tree/main/RustOnAWS
```
