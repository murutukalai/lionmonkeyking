### rest
```rust
// Rest - Company - Document

use axum::{
    extract::{Multipart, Path},
    response::IntoResponse,
    Extension, Json,
};
use backend_api::{
    company::document::{
        self, DocumentCreateInput, DocumentDetail, DocumentGetListOptions, DocumentInfo,
    },
    ApiListResponse, DBConnection,
};
use sailfish::TemplateOnce;
use serde::Deserialize;

use crate::{
    route::rest::{
        convert, helper, RestAuthUser, RestCommonResponse, RestContentResponse, RestError,
        RestResult,
    },
    state::ExtAppState,
};

#[cfg(not(feature = "with-s3"))]
use std::env;

#[cfg(not(feature = "with-s3"))]
use std::{fs, path};

#[derive(Debug, Deserialize)]
pub struct RestDocumentGetListOptions {
    keyword: Option<String>,
    show_all: Option<String>,
    page_no: String,
    sort_by: Option<String>,
    sort_asc: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct RestDocumentUpdateInput {
    title: Option<String>,
    tags: Option<Vec<String>>,
    version: Option<String>,
}

struct RestDocumentInfo {
    title: String,
    size: String,
    file_type: String,
    file_path: String,
}

#[derive(TemplateOnce)]
#[template(path = "includes/company/document_grid.stpl")]
pub struct TemplateDocumentGrid {
    grid: ApiListResponse<DocumentDetail>,
    has_edit_access: bool,
    has_delete_access: bool,
    has_archive_access: bool,
    has_download_access: bool,
    from_row: i64,
    to_row: i64,
}

pub async fn handler_grid(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
    Json(options): Json<RestDocumentGetListOptions>,
) -> RestResult<RestContentResponse> {
    let db = app_state.db.conn().await?;
    let acl = user.get_acl();

    acl.check_privilege(&db, user.id, "company", "document", "view", None)
        .await?;

    let api_input = DocumentGetListOptions {
        keyword: convert::to_string_optional(&options.keyword),
        show_all: Some(convert::to_bool_optional(&options.show_all) == Some(true)),
        sort_by: convert::to_string_optional(&options.sort_by),
        sort_asc: convert::to_bool_optional(&options.sort_asc),
        page_no: convert::to_i64(&options.page_no, "Unable to convert page number")?,
    };

    let grid = document::get_list(&db, &api_input).await?;
    let (from_row, to_row) = helper::calc_row(grid.total_rows, grid.page_no);

    let ctx = TemplateDocumentGrid {
        grid,
        from_row,
        to_row,
        has_edit_access: acl.has_privilege("company", "document", "edit", None),
        has_delete_access: acl.has_privilege("company", "document", "delete", None),
        has_archive_access: acl.has_privilege("company", "document", "archive", None),
        has_download_access: acl.has_privilege("company", "document", "download", None),
    };

    Ok(Json(RestContentResponse {
        success: true,
        content: Some(ctx.render_once().unwrap()),
        error: None,
    }))
}

pub async fn handler_create(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
    mut multipart: Multipart,
) -> RestResult<RestCommonResponse> {
    let db = app_state.db.conn().await?;
    user.get_acl()
        .check_privilege(&db, user.id, "company", "document", "add", None)
        .await?;

    let mut doc_details: Vec<RestDocumentInfo> = vec![];
    let mut tags = vec![];
    let mut version: i16 = 0;

    while let Some(mut field) = multipart.next_field().await.unwrap() {
        match field.name() {
            #[cfg(not(feature = "with-s3"))]
            Some("file") => {
                if field.file_name().is_some() && Some("") != field.file_name() {
                    let cur_dir =
                        env::current_dir().map_err(|err| RestError::Error(format!("{}", err)))?;

                    let Some(cur_dir) = cur_dir.to_str() else {
                        return Err(RestError::Error(
                            "Unable to get current directory".to_string(),
                        ));
                    };

                    if !path::Path::new(&format!("{cur_dir}/public/documents")).exists() {
                        let Ok(_) = fs::create_dir(format!("{cur_dir}/public/documents")) else {
                            tracing::error!("Unable to create dir");
                            return Err(RestError::Error("UNSUPPORTED_MEDIA_TYPE".to_string()));
                        };
                    };

                    let store =
                        storage::DocumentStore::create(&format!("{}/public/documents", cur_dir))?;
                    let doc_infos = store.create_documents(&mut field, "/company_doc").await?;

                    let mut detail = RestDocumentInfo {
                        file_path: "".to_string(),
                        title: "".to_string(),
                        size: "".to_string(),
                        file_type: "".to_string(),
                    };

                    if let Some(doc) = doc_infos.first() {
                        detail.file_path = format!("{}/{}", doc.file_path, doc.file_name);
                        detail.size = doc.size.clone();
                    }

                    let file_name = if let Some(name) = field.file_name() {
                        name.to_string()
                    } else {
                        "file".to_string()
                    };

                    detail.title =
                        if let Some(title) = file_name.split('.').collect::<Vec<&str>>().first() {
                            title.to_string()
                        } else {
                            "file".to_string()
                        };
                    detail.file_type = storage::content_type::to_type(&file_name);

                    doc_details.push(detail);
                }
            }

            #[cfg(feature = "with-s3")]
            Some("file") => {
                if field.file_name().is_some() && Some("") != field.file_name() {
                    let store = storage::DocumentStore::create("documents").unwrap();
                    let doc_infos = store.create_documents(&mut field, "company_doc/").await?;

                    let mut detail = RestDocumentInfo {
                        file_path: "".to_string(),
                        title: "".to_string(),
                        size: "".to_string(),
                        file_type: "".to_string(),
                    };

                    if let Some(doc) = doc_infos.first() {
                        detail.file_path = format!("{}/{}", doc.file_path, doc.file_name);
                        detail.size = doc.size.clone();
                    }

                    let file_name = if let Some(name) = field.file_name() {
                        name.to_string()
                    } else {
                        "file".to_string()
                    };

                    detail.title =
                        if let Some(title) = file_name.split('.').collect::<Vec<&str>>().first() {
                            title.to_string()
                        } else {
                            "file".to_string()
                        };
                    detail.file_type = storage::content_type::to_type(&file_name);

                    doc_details.push(detail);
                }
            }
            Some("tags") => tags.push(field.text().await?),
            Some("version") => {
                version = convert::to_i16(&field.text().await?, "Unable to convert version")?;
            }
            _ => {}
        }
    }

    let tags = if tags.is_empty() { None } else { Some(tags) };

    for docs in doc_details.iter() {
        let api_input = DocumentCreateInput {
            created_by_id: user.id,
            created_by: user.name.to_owned(),
            title: docs.title.to_owned(),
            tags: tags.to_owned(),
            size: docs.size.to_owned(),
            file_type: docs.file_type.to_owned(),
            version,
            file_path: docs.file_path.to_owned(),
        };

        let _ = document::create(&db, &api_input).await?;
    }

    Ok(Json(RestCommonResponse {
        success: !doc_details.is_empty(),
        error: None,
    }))
}

pub async fn handler_update(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
    Path(document_id): Path<i64>,
    Json(input): Json<RestDocumentUpdateInput>,
) -> RestResult<RestCommonResponse> {
    let db = app_state.db.conn().await?;
    user.acl
        .check_privilege(&db, user.id, "company", "document", "edit", None)
        .await?;

    let title = input.title;
    let tags = input.tags;
    let version = convert::to_i16_optional(&input.version, "Unable to convert the version")?;
    let success = document::update_by_id(&db, document_id, &title, &tags, &version).await?;

    Ok(Json(RestCommonResponse {
        success,
        error: None,
    }))
}

#[derive(TemplateOnce)]
#[template(path = "includes/company/document_modal.stpl")]
pub struct TemplateDocumentModal {
    action_url: String,
    item: DocumentInfo,
}

pub async fn handler_get(
    db: &DBConnection<'_>,
    document_id: i64,
) -> RestResult<RestContentResponse> {
    let item = if document_id != 0 {
        document::get_by_id(db, document_id).await?
    } else {
        DocumentInfo {
            id: 0,
            title: String::new(),
            file_path: String::new(),
            version: 1,
            tags: vec![],
        }
    };
    let action_url = if document_id != 0 {
        format!("/api/company/document/{}", document_id)
    } else {
        "/api/company/document/create".to_string()
    };

    let ctx = TemplateDocumentModal { action_url, item };
    Ok(Json(RestContentResponse {
        success: true,
        error: None,
        content: Some(ctx.render_once().unwrap()),
    }))
}

pub async fn handler_get_create(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
) -> RestResult<RestContentResponse> {
    let db = app_state.db.conn().await?;
    user.acl
        .check_privilege(&db, user.id, "company", "document", "add", None)
        .await?;

    handler_get(&db, 0).await
}

pub async fn handler_get_edit(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
    Path(document_id): Path<i64>,
) -> RestResult<RestContentResponse> {
    let db = app_state.db.conn().await?;
    user.acl
        .check_privilege(&db, user.id, "company", "document", "edit", None)
        .await?;

    handler_get(&db, document_id).await
}

#[cfg(not(feature = "with-s3"))]
pub async fn handler_delete(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
    Path(document_id): Path<i64>,
) -> RestResult<RestCommonResponse> {
    let db = app_state.db.conn().await?;

    user.acl
        .check_privilege(&db, user.id, "company", "document", "delete", None)
        .await?;

    let file_path = document::get_by_id(&db, document_id).await?.file_path;
    let cur_dir = env::current_dir().map_err(|err| RestError::Error(format!("{}", err)))?;
    let Some(cur_dir) = cur_dir.to_str() else {
        return Err(RestError::Error(
            "Unable to get current directory".to_string(),
        ));
    };

    let store = storage::DocumentStore::create(&format!("{}/public/documents", cur_dir))?;
    store.delete(file_path.as_str()).await?;

    let success = document::delete_by_id(&db, document_id).await?;
    Ok(Json(RestCommonResponse {
        success,
        error: None,
    }))
}

#[cfg(feature = "with-s3")]
pub async fn handler_delete(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
    Path(document_id): Path<i64>,
) -> RestResult<RestCommonResponse> {
    let db = app_state.db.conn().await?;

    user.acl
        .check_privilege(&db, user.id, "company", "document", "delete", None)
        .await?;

    let file_path = document::get_by_id(&db, document_id).await?.file_path;

    let store = storage::DocumentStore::create("documents").unwrap();
    store.delete(file_path.as_str()).await?;

    let success = document::delete_by_id(&db, document_id).await?;
    Ok(Json(RestCommonResponse {
        success,
        error: None,
    }))
}

pub async fn handler_archive(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
    Path(document_id): Path<i64>,
) -> RestResult<RestCommonResponse> {
    let db = app_state.db.conn().await?;

    user.acl
        .check_privilege(&db, user.id, "company", "document", "archive", None)
        .await?;

    let success = document::update_archive(&db, document_id).await?;

    Ok(Json(RestCommonResponse {
        success,
        error: None,
    }))
}

#[cfg(not(feature = "with-s3"))]
pub async fn handler_download(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
    Path(document_id): Path<i64>,
) -> Result<impl IntoResponse, RestError> {
    let db = app_state.db.conn().await?;

    user.acl
        .check_privilege(&db, user.id, "company", "document", "download", None)
        .await?;

    let document = document::get_by_id(&db, document_id).await?;
    let file_path = document.file_path;
    let file_name = document.title;

    let cur_dir = env::current_dir().map_err(|err| RestError::Error(format!("{}", err)))?;
    let Some(cur_dir) = cur_dir.to_str() else {
        return Err(RestError::Error(
            "Unable to get current directory".to_string(),
        ));
    };

    let store = storage::DocumentStore::create(&format!("{}/public/documents", cur_dir))?;
    Ok(store.download(&file_path, &file_name).await?)
}

#[cfg(feature = "with-s3")]
pub async fn handler_download(
    user: RestAuthUser,
    Extension(app_state): ExtAppState,
    Path(document_id): Path<i64>,
) -> Result<impl IntoResponse, RestError> {
    let db = app_state.db.conn().await?;

    user.acl
        .check_privilege(&db, user.id, "company", "document", "download", None)
        .await?;

    let document = document::get_by_id(&db, document_id).await?;
    let file_path = document.file_path;
    let file_name = document.title;

    let store = storage::DocumentStore::create("documents").unwrap();
    Ok(store.download(&file_path, &file_name).await?)
}

```

### libs/storage/content_type.rs
```rust
// Storage - content-type

pub fn to_type(file_name: &str) -> String {
    if let Some(content_type) = mime_guess::from_path(file_name).first() {
        match content_type.to_string().as_str() {
            "application/pdf" => "Pdf",
            "image/jpeg" => "Jpeg",
            "application/msword" => "Doc",
            "image/png" => "Png",
            "application/vnd.ms-powerpoint" => "Ppt",
            "image/svg+xml" => "Svg",
            "application/octet-stream" => "OctetStream",
            "text/plain" => "PlainText",
            "text/html" => "Html",
            "application/json" => "Json",
            "application/xml" => "Xml",
            "image/gif" => "Gif",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document" => "Docx",
            "application/vnd.openxmlformats-officedocument.presentationml.presentation" => "Pptx",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" => "Xlsx",
            "application/zip" => "Zip",
            "audio/mpeg" => "Mp3",
            "video/mp4" => "Mp4",
            "video/x-msvideo" => "Avi",
            "application/vnd.android.package-archive" => "Apk",
            "application/x-msdownload" => "Exe",
            "application/x-shockwave-flash" => "Swf",
            "application/x-tar" => "Tar",
            "application/x-rar-compressed" => "Rar",
            "application/x-gzip" => "Gzip",
            "application/x-bzip2" => "Bzip2",
            "application/x-7z-compressed" => "SevenZip",
            "application/x-msmetafile" => "Wmf",
            "application/x-ms-wmp" => "Wmp",
            "application/x-java-archive" => "Jar",
            "application/x-bittorrent" => "Torrent",
            "application/x-pkcs12" => "P12",
            "application/x-pkcs7-certificates" => "P7b",
            "application/x-pkcs7-certreqresp" => "P7r",
            "application/x-chrome-extension" => "Crx",
            "application/x-mozilla-extension" => "Xpi",
            "application/ogg" => "Ogg",
            "audio/x-wav" => "Wav",
            "audio/ogg" => "Oga",
            "video/ogg" => "Ogv",
            "application/vnd.apple.installer+xml" => "Mpk",
            "application/vnd.apple.keynote" => "Key",
            "application/vnd.apple.pages" => "Pages",
            "application/vnd.apple.numbers" => "Numbers",
            "application/vnd.ms-excel" => "Xls",
            "application/vnd.ms-word" => "Doc",
            "application/vnd.oasis.opendocument.presentation" => "Odp",
            "application/vnd.oasis.opendocument.spreadsheet" => "Ods",
            "application/vnd.oasis.opendocument.text" => "Odt",
            "audio/midi" => "Midi",
            "audio/mod" => "Mod",
            "audio/x-flac" => "Flac",
            "audio/x-m4a" => "M4a",
            "audio/x-ms-wma" => "Wma",
            "audio/x-pn-realaudio" => "Rm",
            "audio/x-realaudio" => "Ra",
            "image/bmp" => "Bmp",
            "image/tiff" => "Tiff",
            "image/vnd.adobe.photoshop" => "Psd",
            "text/csv" => "Csv",
            "text/markdown" => "Markdown",
            "text/x-vcard" => "Vcard",
            "video/3gpp" => "3gpp",
            "video/quicktime" => "Mov",
            "video/webm" => "Webm",
            "application/vnd.rn-realmedia" => "Rm",
            "application/vnd.rn-realmedia-vbr" => "Rm",
            "application/x-director" => "Dcr",
            "application/x-mpegurl" => "M3u",
            "application/x-ms-wax" => "Wax",
            "application/x-ms-wmx" => "Wmx",
            "application/x-subrip" => "Srt",
            "audio/x-aac" => "Aac",
            "audio/x-aiff" => "Aif",
            "audio/x-wavpack" => "Wv",
            "audio/x-musepack" => "Mpc",
            "image/vnd.djvu" => "Djvu",
            "text/x-asm" => "Asm",
            "text/x-c" => "C",
            "text/x-c++" => "Cpp",
            "text/x-csharp" => "Cs",
            "text/x-fortran" => "Fortran",
            "text/x-java-source" => "Java",
            "text/x-perl" => "Perl",
            "text/x-python" => "Python",
            "text/x-shellscript" => "ShellScript",
            "text/x-php" => "Php",
            "application/x-ruby" => "Ruby",
            "application/x-python" => "Python",
            "application/x-perl" => "Perl",
            "application/x-php" => "Php",
            "application/x-shellscript" => "ShellScript",
            "text/css" => "Css",
            "application/javascript" => "Javascript",
            "application/x-typescript" => "Typescript",
            "text/x-go" => "Go",
            "text/x-markdown" => "Markdown",
            "text/x-ocaml" => "Ocaml",
            "text/x-rust" => "Rust",
            "text/x-scala" => "Scala",
            "text/x-swift" => "Swift",
            "text/x-vhdl" => "Vhdl",
            "text/x-xml" => "Xml",
            "application/xml-dtd" => "XmlDtd",
            "text/x-yaml" => "Yaml",
            "application/x-tex" => "Tex",
            "application/x-latex" => "Latex",
            "application/x-bibtex" => "Bibtex",
            "application/x-research-info-systems" => "Ris",
            "application/x-endnote-refer" => "Enw",
            "application/x-mobipocket-ebook" => "Mobi",
            "application/epub+zip" => "Epub",
            "application/vnd.amazon.ebook" => "Azw",
            "application/x-fictionbook+xml" => "Fb2",
            "application/x-palm-database" => "Pdb",
            "application/x-rocketbook" => "Rb",
            "application/x-tgif" => "Tgif",
            "application/x-blender" => "Blend",
            "application/x-cd-image" => "Iso",
            "application/x-deb" => "Deb",
            "application/x-rpm" => "Rpm",
            "application/vnd.ms-access" => "Mdb",
            "application/vnd.ms-project" => "Mpp",
            "application/vnd.oasis.opendocument.chart" => "Odc",
            "application/vnd.oasis.opendocument.database" => "Odb",
            "application/vnd.oasis.opendocument.formula" => "Odf",
            "application/vnd.oasis.opendocument.graphics" => "Odga",
            "application/vnd.oasis.opendocument.image" => "Odi",
            "application/vnd.oasis.opendocument.text-master" => "Odm",
            "application/vnd.oasis.opendocument.text-web" => "Odw",
            "application/vnd.oasis.opendocument.text-template" => "Ott",
            "application/vnd.oasis.opendocument.graphics-template" => "Otg",
            "application/vnd.oasis.opendocument.presentation-template" => "Otp",
            "application/vnd.oasis.opendocument.spreadsheet-template" => "Ots",
            "application/vnd.oasis.opendocument.chart-template" => "Otc",
            "application/vnd.oasis.opendocument.image-template" => "Oti",
            "application/vnd.oasis.opendocument.formula-template" => "Otf",
            "application/vnd.amazon.mobi8-ebook" => "Kf8",
            "application/vnd.google-earth.kml+xml" => "Kml",
            "application/vnd.google-earth.kmz" => "Kmz",
            "application/x-quicktimeplayer" => "Mov",
            "application/x-lzh-compressed" => "Lzh",
            "application/x-compress" => "Compress",
            "application/x-apple-diskimage" => "Dmg",
            "application/x-java-jnlp-file" => "Jnlp",
            "application/x-ms-shortcut" => "Lnk",
            "application/x-ms-wmz" => "Wmz",
            "application/x-ms-xbap" => "Xbap",
            "application/x-netcdf" => "Nc",
            "application/x-redhat-package-manager" => "Rpm",
            "application/x-troff" => "Troff",
            "application/x-troff-man" => "Man",
            "application/x-troff-me" => "Me",
            "application/x-troff-ms" => "Ms",
            "application/x-troff-msvideo" => "Msvideo",
            "application/x-ustar" => "Ustar",
            "application/x-wais-source" => "Wais",
            "application/x-webarchive" => "Webarchive",
            "application/x-webarchive-xml" => "WebarchiveXml",
            "application/x-www-form-urlencoded" => "WwwFormUrlencoded",
            "audio/x-mpegurl" => "M3u",
            "audio/xm" => "Xm",
            "font/otf" => "Otf",
            "font/ttf" => "Ttf",
            "image/cgm" => "Cgm",
            "image/g3fax" => "G3fax",
            "image/ief" => "Ief",
            "image/ktx" => "Ktx",
            "image/prs.btif" => "Btif",
            "image/vnd.dwg" => "Dwg",
            "image/vnd.dxf" => "Dxf",
            "image/vnd.microsoft.icon" => "Ico",
            "image/webp" => "Webp",
            "image/x-3ds" => "Threeds",
            "image/x-cmu-raster" => "Ras",
            "image/x-portable-anymap" => "Pnm",
            "image/x-portable-bitmap" => "Pbm",
            "image/x-portable-graymap" => "Pgm",
            "image/x-portable-pixmap" => "Ppm",
            "image/x-rgb" => "Rgb",
            "image/x-xbitmap" => "Xbm",
            "image/x-xpixmap" => "Xpm",
            "image/x-xwindowdump" => "Xwd",
            "message/rfc822" => "Rfc822",
            "model/iges" => "Iges",
            "model/mesh" => "Mesh",
            "model/vrml" => "Vrml",
            "model/x3d+binary" => "X3db",
            "model/x3d+vrml" => "X3dv",
            "model/x3d+xml" => "X3d",
            "text/calendar" => "Calendar",
            "text/n3" => "N3",
            "text/prs.lines.tag" => "LinesTag",
            "text/richtext" => "Richtext",
            "text/sgml" => "Sgml",
            "text/tab-separated-values" => "Tsv",
            "text/troff" => "Troff",
            "text/turtle" => "Turtle",
            "text/uri-list" => "UriList",
            "text/vcard" => "Vcard",
            "text/vnd.curl" => "Curl",
            "text/vnd.curl.dcurl" => "Dcurl",
            "text/vnd.curl.mcurl" => "Mcurl",
            "text/vnd.curl.scurl" => "Scurl",
            "text/vnd.dvb.subtitle" => "DvbSubtitle",
            "text/vnd.fly" => "Fly",
            "text/vnd.fmi.flexstor" => "Flexstor",
            "text/vnd.graphviz" => "Graphviz",
            "text/vnd.in3d.3dml" => "3dml",
            "text/vnd.in3d.spot" => "Spot",
            "text/vnd.sun.j2me.app-descriptor" => "Jad",
            "text/vnd.wap.wml" => "Wml",
            "text/vnd.wap.wmlscript" => "Wmlscript",
            "text/x-c++hdr" => "Hpp",
            "text/x-c++src" => "Cpp",
            "text/x-chdr" => "H",
            "text/x-component" => "Component",
            "text/x-lilypond" => "Lilypond",
            "text/x-nfo" => "Nfo",
            "text/x-opml" => "Opml",
            "text/x-pascal" => "Pascal",
            "text/x-setext" => "Setext",
            "text/x-sfv" => "Sfv",
            "text/x-uuencode" => "Uuencode",
            "text/x-vcalendar" => "Vcalendar",
            "text/x-www-form-urlencoded" => "WwwFormUrlencoded",
            "text/x-xmi" => "Xmi",
            "video/3gpp2" => "ThreeGpp2",
            "video/h261" => "H261",
            "video/h263" => "H263",
            "video/h264" => "H264",
            "video/jpeg" => "JpegVideo",
            "video/jpm" => "Jpm",
            "video/mj2" => "Mj2",
            "video/mpeg" => "Mpeg",
            "video/vnd.dece.hd" => "DeceHd",
            "video/vnd.dece.mobile" => "DeceMobile",
            "video/vnd.dece.pd" => "DecePd",
            "video/vnd.dece.sd" => "DeceSd",
            "video/vnd.dece.video" => "DeceVideo",
            "video/vnd.fvt" => "Fvt",
            "video/vnd.mpegurl" => "Mpegurl",
            "video/vnd.ms-playready.media.pyv" => "Pyv",
            "video/vnd.uvvu.mp4" => "UvvuMp4",
            "video/vnd.vivo" => "Vivo",
            "video/x-f4v" => "F4v",
            "video/x-fli" => "Fli",
            "video/x-flv" => "Flv",
            "video/x-m4v" => "M4v",
            "video/x-matroska" => "Matroska",
            "video/x-ms-asf" => "Asf",
            "video/x-ms-wm" => "Wm",
            "video/x-ms-wmv" => "Wmv",
            "video/x-ms-wmx" => "Wmx",
            "video/x-ms-wvx" => "Wvx",
            "video/x-sgi-movie" => "SgiMovie",
            "video/x-smv" => "Smv",
            "x-conference/x-cooltalk" => "Cooltalk",
            exe => exe,
        }
        .to_string()
    } else if let Some(exe) = file_name.split('.').last() {
        exe.to_string()
    } else {
        "Unknown".to_string()
    }
}

```

### lib/storage
```rust
// Libs - Storage

use axum::{extract::multipart::Field, http::header, response::IntoResponse};
use futures::stream::StreamExt;
use tokio::io::AsyncWriteExt;

#[cfg(not(feature = "with-s3"))]
use std::path;

#[cfg(not(feature = "with-s3"))]
use object_store::{self, local::LocalFileSystem, path::Path, ObjectStore};

#[cfg(feature = "with-s3")]
use object_store::{
    self,
    aws::{AmazonS3, AmazonS3Builder},
    path::Path,
    ObjectStore,
};

pub mod content_type;

#[derive(thiserror::Error, Debug)]
pub enum DocumentStoreError {
    // Common Error
    #[error("Error: {0}")]
    Error(String),

    // Object Store Error
    #[error("Parse error: {0}")]
    ObjectError(#[from] object_store::Error),
}

#[cfg(feature = "with-s3")]
pub struct DocumentStore {
    store: AmazonS3,
    _store_type: String,
    _initial_path: String,
}

#[cfg(not(feature = "with-s3"))]
pub struct DocumentStore {
    store: LocalFileSystem,
    _store_type: String,
    _initial_path: String,
}

#[derive(Debug, Clone)]
pub struct DocumentInfo {
    pub file_path: String,
    pub file_name: String,
    pub size: String,
}

impl DocumentStore {
    #[cfg(feature = "with-s3")]
    pub fn create(initial_path: &str) -> Result<DocumentStore, DocumentStoreError> {
        Ok(DocumentStore {
            store: AmazonS3Builder::from_env()
                .with_bucket_name(initial_path)
                .build()?,
            _store_type: "S3".to_string(),
            _initial_path: initial_path.to_string(),
        })
    }

    #[cfg(not(feature = "with-s3"))]
    pub fn create(initial_path: &str) -> Result<DocumentStore, DocumentStoreError> {
        let path = path::Path::new(initial_path);
        Ok(DocumentStore {
            store: LocalFileSystem::new_with_prefix(path)?,
            _store_type: "Local Store".to_string(),
            _initial_path: initial_path.to_string(),
        })
    }

    pub async fn get_list(&self, path: &str) -> Result<Vec<DocumentInfo>, DocumentStoreError> {
        let prefix = Path::from(path);
        let mut list_stream = self.store.list(Some(&prefix));
        let mut items: Vec<DocumentInfo> = vec![];
        while let Some(meta) = list_stream.next().await.transpose()? {
            let file_name = if let Some(name) = meta.location.filename() {
                name.to_string()
            } else {
                String::new()
            };

            items.push(DocumentInfo {
                file_path: meta.location.to_string(),
                file_name,
                size: bytesize::ByteSize::to_string_as(
                    &bytesize::ByteSize::b(meta.size as u64),
                    true,
                )
                .to_string(),
            });
        }
        Ok(items)
    }

    pub async fn create_documents(
        &self,
        field: &mut Field<'_>,
        path: &str,
    ) -> Result<Vec<DocumentInfo>, DocumentStoreError> {
        let mut doc_info: Vec<DocumentInfo> = vec![];

        let Some(_) = field.content_type().map(ToString::to_string) else {
            return Err(DocumentStoreError::Error(
                "Unsupported content type".to_string(),
            ));
        };

        let Some(file_name) = field.file_name().map(ToString::to_string) else {
            return Err(DocumentStoreError::Error(
                "Unable to get the file name".to_string(),
            ));
        };

        let file_exe = if let Some(exe) = file_name.split('.').last() {
            exe
        } else {
            ""
        };

        let mut data_len = 0;
        let doc_id = uuid::Uuid::new_v4();
        let file_path = Path::from(format!("{}/{}.{}", path, doc_id, file_exe));
        let (_id, mut writer) = self.store.put_multipart(&file_path).await?;
        loop {
            let Some(data) = field
                .chunk()
                .await
                .map_err(|err| DocumentStoreError::Error(err.to_string()))?
            else {
                break;
            };

            data_len += data.len() as u64;
            writer
                .write_all(&data)
                .await
                .map_err(|err| DocumentStoreError::Error(err.to_string()))?;
            writer
                .flush()
                .await
                .map_err(|err| DocumentStoreError::Error(err.to_string()))?;
        }
        doc_info.push(DocumentInfo {
            file_path: path.to_string(),
            file_name: format!("{}.{}", doc_id, file_exe),
            size: bytesize::ByteSize::to_string_as(&bytesize::ByteSize::b(data_len), true)
                .to_string(),
        });
        writer
            .shutdown()
            .await
            .map_err(|err| DocumentStoreError::Error(err.to_string()))?;

        Ok(doc_info)
    }

    pub async fn get_content(&self, path: &str) -> Result<bytes::Bytes, DocumentStoreError> {
        let path = Path::from(path);
        let result = self.store.get(&path).await?;
        Ok(result.bytes().await?)
    }

    pub async fn delete(&self, path: &str) -> Result<(), DocumentStoreError> {
        let path = Path::from(path);
        Ok(self.store.delete(&path).await?)
    }

    pub async fn download(
        &self,
        path: &str,
        file_name: &str,
    ) -> Result<impl IntoResponse, DocumentStoreError> {
        let file_path = Path::from(path);
        let result = self.store.get(&file_path).await?;

        let Some(file_exe) = path.split('.').last() else {
            return Err(DocumentStoreError::Error(
                "Unable to fetch file extension".to_string(),
            ));
        };

        let Some(content_type) = mime_guess::from_path(file_name).first() else {
            return Err(DocumentStoreError::Error(
                "Unable to get the content type".to_string(),
            ));
        };
        let headers = [
            (
                header::CONTENT_TYPE,
                format!("{}; charset=utf-8", content_type).to_owned(),
            ),
            (
                header::CONTENT_DISPOSITION,
                format!("attachment; filename=\"{}.{}\"", file_name, file_exe).to_owned(),
            ),
        ];

        Ok((headers, result.bytes().await?))
    }
}

```
