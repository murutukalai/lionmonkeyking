let date = NaiveDate::from_ymd_opt(yyyy, mm, dd).unwrap();
let time = NaiveTime::from_hms_opt(hour, min, 0).unwrap();
let naive_datetime = NaiveDateTime::new(date, time);
let utc_datetime = DateTime::<Utc>::from_naive_utc_and_offset(naive_datetime, Utc);
