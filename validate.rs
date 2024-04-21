#[derive(Debug, Deserialize, Validate)]
pub struct SignUpInput {
    #[validate(length(min = 4), custom(function = "validation::word"))]
    pub name: String,

    #[validate(email(message = "enter a valid email"))]
    pub email: String,

    #[validate(length(min = 6))]
    pub password: String,

    #[validate(
        length(min = 10, message = "Minimum 10 digits "),
        custom(
            function = "validation::mobile_number",
            message = "Invalid mobile number"
        )
    )]
    pub mobile: Option<String>,
}

if let Err(err) = input.validate() {
    let err_msg = if let Some(err) = err.to_string().split(':').last() {
        err.to_string()
    } else {
        "Invalid data".to_string()
    };
    return Err(ApiError::Error(err_msg));
}

// error msg : `Error: Minimum 10 digits, Invalid mobile number`

// to get user agent

// headers: HeaderMap,
// headers.get("user-agent")
