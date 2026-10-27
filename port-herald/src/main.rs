mod api;
mod api_export;
mod db;
mod models;
mod nmap_parser;
mod scanner;

use actix_web::{middleware, web as actix_web_web, App, HttpRequest, HttpResponse, HttpServer};
use clap::Parser;
use rust_embed::Embed;
use sqlx::SqlitePool;
use std::sync::Arc;
use tokio::sync::RwLock;

#[derive(Embed)]
#[folder = "web/"]
struct WebAssets;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Database file path
    #[arg(short, long, default_value = "portherald.db")]
    database: String,

    /// Server bind address
    #[arg(short, long, default_value = "127.0.0.1")]
    bind: String,

    /// Server port
    #[arg(short, long, default_value = "8080")]
    port: u16,
}

pub struct AppState {
    db: SqlitePool,
    scanner: Arc<RwLock<scanner::ScanManager>>,
}

async fn serve_embedded(req: HttpRequest) -> HttpResponse {
    let mut path = req.match_info().query("path").to_string();
    if path.is_empty() || path == "/" {
        path = "index.html".to_string();
    }
    let path = path.trim_start_matches('/');

    match WebAssets::get(path) {
        Some(content) => {
            let mime = if path.ends_with(".html") {
                "text/html; charset=utf-8"
            } else if path.ends_with(".css") {
                "text/css; charset=utf-8"
            } else if path.ends_with(".js") {
                "application/javascript; charset=utf-8"
            } else if path.ends_with(".json") {
                "application/json"
            } else if path.ends_with(".png") {
                "image/png"
            } else if path.ends_with(".svg") {
                "image/svg+xml"
            } else {
                "application/octet-stream"
            };
            HttpResponse::Ok()
                .insert_header(("Content-Type", mime))
                .insert_header(("Cache-Control", "no-cache, no-store, must-revalidate"))
                .insert_header(("Pragma", "no-cache"))
                .insert_header(("Expires", "0"))
                .body(content.data.to_vec())
        }
        None => HttpResponse::NotFound().body("404 Not Found"),
    }
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    env_logger::init_from_env(env_logger::Env::new().default_filter_or("info"));

    let args = Args::parse();

    log::info!("Starting Port Herald...");

    // Initialize database
    let db_url = format!("sqlite://{}?mode=rwc", args.database);
    let pool = SqlitePool::connect(&db_url)
        .await
        .expect("Failed to connect to database");

    // Run migrations
    db::migrate(&pool).await.expect("Failed to run migrations");

    log::info!("Database initialized at {}", args.database);

    // Initialize scanner
    let scanner = Arc::new(RwLock::new(scanner::ScanManager::new()));

    let state = actix_web_web::Data::new(AppState { db: pool, scanner });

    let bind_addr = format!("{}:{}", args.bind, args.port);
    log::info!("Starting server at http://{}", bind_addr);
    log::info!("Open your browser to http://{}:{}", args.bind, args.port);

    HttpServer::new(move || {
        App::new()
            .app_data(state.clone())
            .wrap(middleware::Logger::default())
            .wrap(actix_cors::Cors::permissive())
            .configure(api::configure)
            .route(
                "/",
                actix_web_web::get().to(|req: HttpRequest| serve_embedded(req)),
            )
            .route("/{path:.*}", actix_web_web::get().to(serve_embedded))
    })
    .bind(&bind_addr)?
    .run()
    .await
}
