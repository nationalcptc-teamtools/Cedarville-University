use crate::{api_export, db, models::*, nmap_parser, AppState};
use actix_web::{web, HttpResponse, Responder};
use serde::Deserialize;

pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/api")
            .route("/health", web::get().to(health))
            .route("/hosts", web::get().to(get_hosts))
            .route("/hosts/{id}", web::get().to(get_host_detail))
            .route("/hosts/{id}", web::delete().to(delete_host))
            .route("/hosts/{id}/assign", web::post().to(assign))
            .route("/hosts/{id}/unassign", web::post().to(unassign))
            .route("/hosts/{id}/status", web::put().to(update_status))
            .route("/hosts/{id}/notes", web::get().to(get_notes))
            .route("/hosts/{id}/notes", web::post().to(add_note))
            .route("/networks", web::get().to(get_networks))
            .route("/topology", web::get().to(get_topology))
            .route("/scans", web::get().to(get_scans))
            .route("/scans", web::post().to(start_scan))
            .route("/scans/active", web::get().to(list_active_scans))
            .route("/scans/{id}/status", web::get().to(get_scan_status))
            .route("/scans/{id}/logs", web::get().to(get_scan_logs))
            .route("/scans/{id}/cancel", web::post().to(cancel_scan))
            .route("/import", web::post().to(import_nmap))
            // Team
            .route("/members", web::get().to(get_members))
            .route("/members", web::post().to(add_members))
            .route("/members/{id}", web::delete().to(delete_member))
            .route("/members/{id}/icon", web::put().to(update_member_icon))
            .route(
                "/members/{id}/assignments",
                web::get().to(member_assignments),
            )
            .route("/members/{id}/blame", web::get().to(member_blame))
            .route("/blame", web::get().to(all_blame))
            // Export
            .route("/export/{format}", web::get().to(api_export::export))
            .route(
                "/notes/export/{format}",
                web::get().to(api_export::export_notes),
            ),
    );
}

async fn health() -> impl Responder {
    HttpResponse::Ok().json(serde_json::json!({
        "status": "ok",
        "version": env!("CARGO_PKG_VERSION")
    }))
}

// ── Hosts ────────────────────────────────────────────────────────────

async fn get_hosts(state: web::Data<AppState>) -> impl Responder {
    match db::get_all_hosts(&state.db).await {
        Ok(hosts) => HttpResponse::Ok().json(hosts),
        Err(e) => {
            log::error!("get_hosts: {}", e);
            HttpResponse::InternalServerError().json(serde_json::json!({"error": "failed"}))
        }
    }
}

async fn get_host_detail(state: web::Data<AppState>, path: web::Path<i64>) -> impl Responder {
    let host_id = path.into_inner();

    let host = match db::get_host_by_id(&state.db, host_id).await {
        Ok(Some(h)) => h,
        Ok(None) => {
            return HttpResponse::NotFound().json(serde_json::json!({"error": "host not found"}))
        }
        Err(e) => {
            log::error!("get_host: {}", e);
            return HttpResponse::InternalServerError().finish();
        }
    };

    let ports = db::get_ports_for_host(&state.db, host_id)
        .await
        .unwrap_or_default();
    let mut ports_with_scripts = Vec::new();
    for port in ports {
        let scripts = db::get_scripts_for_port(&state.db, port.id)
            .await
            .unwrap_or_default();
        ports_with_scripts.push(PortWithScripts { port, scripts });
    }

    let assignments = db::active_assignments_for_host(&state.db, host_id)
        .await
        .unwrap_or_default();
    let notes = db::get_host_notes(&state.db, host_id)
        .await
        .unwrap_or_default();

    HttpResponse::Ok().json(HostFull {
        host,
        ports: ports_with_scripts,
        assignments,
        notes,
    })
}

#[derive(Deserialize)]
struct DeleteHostQuery {
    #[serde(default)]
    member_id: Option<i64>,
}

async fn delete_host(
    state: web::Data<AppState>,
    path: web::Path<i64>,
    q: web::Query<DeleteHostQuery>,
) -> impl Responder {
    let host_id = path.into_inner();

    // Capture a human-readable label *before* we delete, so the blame entry
    // can still show "192.168.1.5" after the row is gone.
    let host = match db::get_host_by_id(&state.db, host_id).await {
        Ok(Some(h)) => h,
        Ok(None) => {
            return HttpResponse::NotFound().json(serde_json::json!({"error": "host not found"}))
        }
        Err(e) => {
            log::error!("delete_host lookup: {}", e);
            return HttpResponse::InternalServerError().finish();
        }
    };

    match db::delete_host(&state.db, host_id).await {
        Ok(_) => {
            let _ = db::log_blame(
                &state.db,
                q.member_id,
                "host_removed",
                "host",
                host_id,
                Some(&host.ip_address),
            )
            .await;
            HttpResponse::Ok().json(serde_json::json!({
                "status": "deleted",
                "ip_address": host.ip_address
            }))
        }
        Err(e) => {
            log::error!("delete_host: {}", e);
            HttpResponse::InternalServerError().json(serde_json::json!({"error": e.to_string()}))
        }
    }
}

async fn get_networks(state: web::Data<AppState>) -> impl Responder {
    match db::get_all_networks(&state.db).await {
        Ok(n) => HttpResponse::Ok().json(n),
        Err(e) => {
            log::error!("get_networks: {}", e);
            HttpResponse::InternalServerError().finish()
        }
    }
}

async fn get_topology(state: web::Data<AppState>) -> impl Responder {
    let networks = db::get_all_networks(&state.db).await.unwrap_or_default();
    let hosts = db::get_all_hosts(&state.db).await.unwrap_or_default();

    let mut hosts_with_ports = Vec::new();
    for host in hosts {
        let ports = db::get_ports_for_host(&state.db, host.id)
            .await
            .unwrap_or_default();
        let mut pws = Vec::new();
        for port in ports {
            let scripts = db::get_scripts_for_port(&state.db, port.id)
                .await
                .unwrap_or_default();
            pws.push(PortWithScripts { port, scripts });
        }
        let assignments = db::active_assignments_for_host(&state.db, host.id)
            .await
            .unwrap_or_default();
        hosts_with_ports.push(HostWithPorts {
            host,
            ports: pws,
            assignments,
        });
    }

    HttpResponse::Ok().json(NetworkTopology {
        networks,
        hosts: hosts_with_ports,
        connections: Vec::new(),
    })
}

// ── Scans ────────────────────────────────────────────────────────────

async fn get_scans(state: web::Data<AppState>) -> impl Responder {
    match db::get_recent_scans(&state.db, 50).await {
        Ok(s) => HttpResponse::Ok().json(s),
        Err(e) => {
            log::error!("get_scans: {}", e);
            HttpResponse::InternalServerError().finish()
        }
    }
}

async fn start_scan(state: web::Data<AppState>, config: web::Json<ScanConfig>) -> impl Responder {
    let mut scanner = state.scanner.write().await;
    match scanner
        .start_scan(config.into_inner(), state.db.clone())
        .await
    {
        Ok(id) => HttpResponse::Ok().json(serde_json::json!({"scan_id": id, "status": "started"})),
        Err(e) => {
            HttpResponse::InternalServerError().json(serde_json::json!({"error": e.to_string()}))
        }
    }
}

async fn get_scan_status(state: web::Data<AppState>, path: web::Path<String>) -> impl Responder {
    let scan_id = path.into_inner();
    let scanner = state.scanner.read().await;
    match scanner.get_scan_status(&scan_id).await {
        Some(s) => HttpResponse::Ok().json(s),
        None => HttpResponse::NotFound().json(serde_json::json!({"error": "scan not found"})),
    }
}

async fn list_active_scans(state: web::Data<AppState>) -> impl Responder {
    // Opportunistic pruning of long-finished scans (older than 10 min)
    {
        let mut m = state.scanner.write().await;
        m.prune(600).await;
    }
    let scanner = state.scanner.read().await;
    HttpResponse::Ok().json(scanner.list_active().await)
}

#[derive(Deserialize)]
struct LogQuery {
    #[serde(default)]
    since: usize,
}

async fn get_scan_logs(
    state: web::Data<AppState>,
    path: web::Path<String>,
    q: web::Query<LogQuery>,
) -> impl Responder {
    let scan_id = path.into_inner();
    let scanner = state.scanner.read().await;
    match scanner.get_logs(&scan_id, q.since).await {
        Some(s) => HttpResponse::Ok().json(s),
        None => HttpResponse::NotFound().json(serde_json::json!({"error": "scan not found"})),
    }
}

async fn cancel_scan(state: web::Data<AppState>, path: web::Path<String>) -> impl Responder {
    let scan_id = path.into_inner();
    let scanner = state.scanner.read().await;
    if scanner.cancel_scan(&scan_id).await {
        HttpResponse::Ok().json(serde_json::json!({"status": "cancelling"}))
    } else {
        HttpResponse::NotFound().json(serde_json::json!({"error": "scan not found"}))
    }
}

#[derive(Deserialize)]
struct ImportRequest {
    xml: String,
}

async fn import_nmap(state: web::Data<AppState>, req: web::Json<ImportRequest>) -> impl Responder {
    match nmap_parser::parse_and_import_nmap_xml(&state.db, &req.xml).await {
        Ok(stats) => HttpResponse::Ok().json(serde_json::json!({
            "status": "success",
            "hosts_imported": stats.hosts_imported,
            "ports_imported": stats.ports_imported,
            "scripts_imported": stats.scripts_imported,
        })),
        Err(e) => {
            HttpResponse::InternalServerError().json(serde_json::json!({"error": e.to_string()}))
        }
    }
}

// ── Team members ─────────────────────────────────────────────────────

async fn get_members(state: web::Data<AppState>) -> impl Responder {
    match db::get_all_members(&state.db).await {
        Ok(m) => HttpResponse::Ok().json(m),
        Err(e) => {
            log::error!("get_members: {}", e);
            HttpResponse::InternalServerError().finish()
        }
    }
}

async fn add_members(
    state: web::Data<AppState>,
    req: web::Json<AddMembersRequest>,
) -> impl Responder {
    let names: Vec<String> = req
        .names
        .split([',', '\n'])
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .collect();

    if names.is_empty() {
        return HttpResponse::BadRequest().json(serde_json::json!({"error": "no names provided"}));
    }

    let mut added = Vec::new();
    for name in names {
        match db::add_member(&state.db, &name).await {
            Ok(m) => added.push(m),
            Err(e) => log::warn!("skip member {}: {}", name, e),
        }
    }

    HttpResponse::Ok().json(serde_json::json!({
        "added": added.len(),
        "members": added,
    }))
}

async fn delete_member(state: web::Data<AppState>, path: web::Path<i64>) -> impl Responder {
    let id = path.into_inner();
    match db::delete_member(&state.db, id).await {
        Ok(_) => {
            let _ = db::log_blame(&state.db, None, "member_removed", "member", id, None).await;
            HttpResponse::Ok().json(serde_json::json!({"status": "removed"}))
        }
        Err(e) => {
            HttpResponse::InternalServerError().json(serde_json::json!({"error": e.to_string()}))
        }
    }
}

async fn member_assignments(state: web::Data<AppState>, path: web::Path<i64>) -> impl Responder {
    let id = path.into_inner();
    match db::active_assignments_for_member(&state.db, id).await {
        Ok(a) => HttpResponse::Ok().json(a),
        Err(e) => {
            HttpResponse::InternalServerError().json(serde_json::json!({"error": e.to_string()}))
        }
    }
}

async fn update_member_icon(
    state: web::Data<AppState>,
    path: web::Path<i64>,
    req: web::Json<UpdateIconRequest>,
) -> impl Responder {
    let id = path.into_inner();
    let icon = req.icon.trim();
    if icon.is_empty() {
        return HttpResponse::BadRequest().json(serde_json::json!({"error": "icon is empty"}));
    }
    // Allow longer values for data: URIs (so custom image icons work),
    // but cap at a sane limit to prevent runaway payloads.
    if icon.len() > 100_000 {
        return HttpResponse::BadRequest()
            .json(serde_json::json!({"error": "icon payload too large (max ~100 KB)"}));
    }
    if db::get_member_by_id(&state.db, id)
        .await
        .ok()
        .flatten()
        .is_none()
    {
        return HttpResponse::NotFound().json(serde_json::json!({"error": "member not found"}));
    }
    match db::update_member_icon(&state.db, id, icon).await {
        Ok(_) => {
            // For blame, record only a short preview if the icon is a data URI
            let preview = if icon.len() > 32 {
                "custom image"
            } else {
                icon
            };
            let _ = db::log_blame(
                &state.db,
                Some(id),
                "icon_changed",
                "member",
                id,
                Some(preview),
            )
            .await;
            HttpResponse::Ok().json(serde_json::json!({"status": "updated", "icon": icon}))
        }
        Err(e) => {
            HttpResponse::InternalServerError().json(serde_json::json!({"error": e.to_string()}))
        }
    }
}

#[derive(Deserialize)]
struct BlameQuery {
    #[serde(default = "default_limit")]
    limit: i64,
}
fn default_limit() -> i64 {
    200
}

async fn member_blame(
    state: web::Data<AppState>,
    path: web::Path<i64>,
    q: web::Query<BlameQuery>,
) -> impl Responder {
    let id = path.into_inner();
    match db::get_blame_log(&state.db, Some(id), q.limit).await {
        Ok(b) => HttpResponse::Ok().json(b),
        Err(e) => {
            HttpResponse::InternalServerError().json(serde_json::json!({"error": e.to_string()}))
        }
    }
}

async fn all_blame(state: web::Data<AppState>, q: web::Query<BlameQuery>) -> impl Responder {
    match db::get_blame_log(&state.db, None, q.limit).await {
        Ok(b) => HttpResponse::Ok().json(b),
        Err(e) => {
            HttpResponse::InternalServerError().json(serde_json::json!({"error": e.to_string()}))
        }
    }
}

// ── Assignments / status / notes ─────────────────────────────────────

async fn assign(
    state: web::Data<AppState>,
    path: web::Path<i64>,
    req: web::Json<AssignRequest>,
) -> impl Responder {
    let host_id = path.into_inner();

    // Verify host and member exist
    if db::get_host_by_id(&state.db, host_id)
        .await
        .ok()
        .flatten()
        .is_none()
    {
        return HttpResponse::NotFound().json(serde_json::json!({"error": "host not found"}));
    }
    if db::get_member_by_id(&state.db, req.member_id)
        .await
        .ok()
        .flatten()
        .is_none()
    {
        return HttpResponse::NotFound().json(serde_json::json!({"error": "member not found"}));
    }

    match db::assign_member(&state.db, req.member_id, host_id, req.port_id).await {
        Ok(aid) => {
            let detail = req.port_id.map(|p| format!("port_id={}", p));
            let _ = db::log_blame(
                &state.db,
                Some(req.member_id),
                "assigned",
                "host",
                host_id,
                detail.as_deref(),
            )
            .await;
            HttpResponse::Ok().json(serde_json::json!({"assignment_id": aid}))
        }
        Err(e) => {
            HttpResponse::InternalServerError().json(serde_json::json!({"error": e.to_string()}))
        }
    }
}

async fn unassign(
    state: web::Data<AppState>,
    path: web::Path<i64>,
    req: web::Json<UnassignRequest>,
) -> impl Responder {
    let host_id = path.into_inner();
    match db::unassign_member(&state.db, req.member_id, host_id).await {
        Ok(_) => {
            let _ = db::log_blame(
                &state.db,
                Some(req.member_id),
                "unassigned",
                "host",
                host_id,
                None,
            )
            .await;
            HttpResponse::Ok().json(serde_json::json!({"status": "unassigned"}))
        }
        Err(e) => {
            HttpResponse::InternalServerError().json(serde_json::json!({"error": e.to_string()}))
        }
    }
}

async fn update_status(
    state: web::Data<AppState>,
    path: web::Path<i64>,
    req: web::Json<StatusUpdateRequest>,
) -> impl Responder {
    let host_id = path.into_inner();
    let allowed = ["untouched", "investigating", "investigated", "compromised"];
    if !allowed.contains(&req.status.as_str()) {
        return HttpResponse::BadRequest().json(serde_json::json!({
            "error": format!("invalid status, expected one of {:?}", allowed)
        }));
    }

    match db::set_investigation_status(&state.db, host_id, &req.status).await {
        Ok(_) => {
            let _ = db::log_blame(
                &state.db,
                req.member_id,
                "status_changed",
                "host",
                host_id,
                Some(&req.status),
            )
            .await;
            HttpResponse::Ok().json(serde_json::json!({"status": req.status}))
        }
        Err(e) => {
            HttpResponse::InternalServerError().json(serde_json::json!({"error": e.to_string()}))
        }
    }
}

async fn get_notes(state: web::Data<AppState>, path: web::Path<i64>) -> impl Responder {
    let host_id = path.into_inner();
    match db::get_host_notes(&state.db, host_id).await {
        Ok(n) => HttpResponse::Ok().json(n),
        Err(e) => {
            HttpResponse::InternalServerError().json(serde_json::json!({"error": e.to_string()}))
        }
    }
}

async fn add_note(
    state: web::Data<AppState>,
    path: web::Path<i64>,
    req: web::Json<NoteCreateRequest>,
) -> impl Responder {
    let host_id = path.into_inner();
    let note = req.note.trim();
    if note.is_empty() {
        return HttpResponse::BadRequest().json(serde_json::json!({"error": "note is empty"}));
    }
    match db::add_host_note(&state.db, host_id, req.member_id, note).await {
        Ok(id) => {
            let _ = db::log_blame(
                &state.db,
                req.member_id,
                "note_added",
                "host",
                host_id,
                Some(&note.chars().take(80).collect::<String>()),
            )
            .await;
            HttpResponse::Ok().json(serde_json::json!({"id": id}))
        }
        Err(e) => {
            HttpResponse::InternalServerError().json(serde_json::json!({"error": e.to_string()}))
        }
    }
}
