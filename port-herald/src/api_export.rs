use crate::{db, models::*, AppState};
use actix_web::{web, HttpResponse, Responder};
use serde::Serialize;
use std::fmt::Write;

#[derive(Serialize)]
struct FullExport {
    exported_at: String,
    networks: Vec<Network>,
    hosts: Vec<HostFull>,
    members: Vec<TeamMember>,
    scans: Vec<Scan>,
    blame_log: Vec<BlameEntry>,
}

async fn gather_full_export(state: &AppState) -> anyhow::Result<FullExport> {
    let networks = db::get_all_networks(&state.db).await.unwrap_or_default();
    let hosts = db::get_all_hosts(&state.db).await.unwrap_or_default();
    let members = db::get_all_members(&state.db).await.unwrap_or_default();
    let scans = db::get_recent_scans(&state.db, 10_000)
        .await
        .unwrap_or_default();
    let blame = db::get_blame_log(&state.db, None, 10_000)
        .await
        .unwrap_or_default();

    let mut full_hosts = Vec::new();
    for h in hosts {
        let ports = db::get_ports_for_host(&state.db, h.id)
            .await
            .unwrap_or_default();
        let mut pws = Vec::new();
        for p in ports {
            let scripts = db::get_scripts_for_port(&state.db, p.id)
                .await
                .unwrap_or_default();
            pws.push(PortWithScripts { port: p, scripts });
        }
        let assignments = db::active_assignments_for_host(&state.db, h.id)
            .await
            .unwrap_or_default();
        let notes = db::get_host_notes(&state.db, h.id)
            .await
            .unwrap_or_default();
        full_hosts.push(HostFull {
            host: h,
            ports: pws,
            assignments,
            notes,
        });
    }

    Ok(FullExport {
        exported_at: chrono::Utc::now().to_rfc3339(),
        networks,
        hosts: full_hosts,
        members,
        scans,
        blame_log: blame,
    })
}

pub async fn export(state: web::Data<AppState>, path: web::Path<String>) -> impl Responder {
    let format = path.into_inner().to_lowercase();
    let data = match gather_full_export(&state).await {
        Ok(d) => d,
        Err(e) => return HttpResponse::InternalServerError().body(e.to_string()),
    };

    match format.as_str() {
        "json" => HttpResponse::Ok()
            .insert_header(("Content-Type", "application/json"))
            .insert_header((
                "Content-Disposition",
                "attachment; filename=\"portherald_export.json\"",
            ))
            .body(serde_json::to_string_pretty(&data).unwrap_or_default()),
        "xml" => HttpResponse::Ok()
            .insert_header(("Content-Type", "application/xml"))
            .insert_header((
                "Content-Disposition",
                "attachment; filename=\"portherald_export.xml\"",
            ))
            .body(render_xml(&data)),
        "txt" => HttpResponse::Ok()
            .insert_header(("Content-Type", "text/plain"))
            .insert_header((
                "Content-Disposition",
                "attachment; filename=\"portherald_export.txt\"",
            ))
            .body(render_txt(&data)),
        _ => HttpResponse::BadRequest()
            .json(serde_json::json!({"error": "format must be json|xml|txt"})),
    }
}

pub async fn export_notes(state: web::Data<AppState>, path: web::Path<String>) -> impl Responder {
    let format = path.into_inner().to_lowercase();
    let notes = db::get_all_host_notes(&state.db).await.unwrap_or_default();
    let hosts = db::get_all_hosts(&state.db).await.unwrap_or_default();
    let host_map: std::collections::HashMap<i64, String> = hosts
        .iter()
        .map(|h| {
            (
                h.id,
                format!(
                    "{}{}",
                    h.ip_address,
                    h.hostname
                        .as_ref()
                        .map(|n| format!(" ({})", n))
                        .unwrap_or_default()
                ),
            )
        })
        .collect();

    match format.as_str() {
        "json" => HttpResponse::Ok()
            .insert_header(("Content-Type", "application/json"))
            .insert_header(("Content-Disposition", "attachment; filename=\"notes.json\""))
            .body(serde_json::to_string_pretty(&notes).unwrap_or_default()),
        "xml" => HttpResponse::Ok()
            .insert_header(("Content-Type", "application/xml"))
            .insert_header(("Content-Disposition", "attachment; filename=\"notes.xml\""))
            .body(render_notes_xml(&notes, &host_map)),
        "txt" => HttpResponse::Ok()
            .insert_header(("Content-Type", "text/plain"))
            .insert_header(("Content-Disposition", "attachment; filename=\"notes.txt\""))
            .body(render_notes_txt(&notes, &host_map)),
        _ => HttpResponse::BadRequest()
            .json(serde_json::json!({"error": "format must be json|xml|txt"})),
    }
}

// ── Rendering ────────────────────────────────────────────────────────

fn xml_escape(s: &str) -> String {
    s.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
        .replace('\'', "&apos;")
}

fn opt_xml(s: &Option<String>) -> String {
    match s {
        Some(v) => xml_escape(v),
        None => String::new(),
    }
}

fn render_xml(d: &FullExport) -> String {
    let mut out = String::new();
    out.push_str("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
    let _ = writeln!(
        out,
        "<portherald_export exported_at=\"{}\">",
        xml_escape(&d.exported_at)
    );

    let _ = writeln!(out, "  <networks>");
    for n in &d.networks {
        let _ = writeln!(
            out,
            "    <network id=\"{}\" cidr=\"{}\"/>",
            n.id,
            xml_escape(&n.cidr)
        );
    }
    let _ = writeln!(out, "  </networks>");

    let _ = writeln!(out, "  <members>");
    for m in &d.members {
        let _ = writeln!(
            out,
            "    <member id=\"{}\" name=\"{}\" icon=\"{}\"/>",
            m.id,
            xml_escape(&m.name),
            xml_escape(&m.icon)
        );
    }
    let _ = writeln!(out, "  </members>");

    let _ = writeln!(out, "  <hosts>");
    for h in &d.hosts {
        let _ = writeln!(out, "    <host id=\"{}\" ip=\"{}\" hostname=\"{}\" os=\"{}\" status=\"{}\" investigation_status=\"{}\">",
            h.host.id,
            xml_escape(&h.host.ip_address),
            opt_xml(&h.host.hostname),
            opt_xml(&h.host.os),
            xml_escape(&h.host.status),
            xml_escape(&h.host.investigation_status),
        );
        let _ = writeln!(out, "      <ports>");
        for pws in &h.ports {
            let p = &pws.port;
            let _ = writeln!(out, "        <port number=\"{}\" protocol=\"{}\" state=\"{}\" service=\"{}\" product=\"{}\" version=\"{}\">",
                p.port_number, xml_escape(&p.protocol), xml_escape(&p.state),
                opt_xml(&p.service), opt_xml(&p.product), opt_xml(&p.version));
            for s in &pws.scripts {
                let _ = writeln!(
                    out,
                    "          <script name=\"{}\"><![CDATA[{}]]></script>",
                    xml_escape(&s.script_name),
                    s.output.replace("]]>", "]]]]><![CDATA[>")
                );
            }
            let _ = writeln!(out, "        </port>");
        }
        let _ = writeln!(out, "      </ports>");

        let _ = writeln!(out, "      <assignments>");
        for a in &h.assignments {
            let port_attr = a
                .port_number
                .map(|n| {
                    format!(
                        " port=\"{}/{}\"",
                        n,
                        a.port_protocol.as_deref().unwrap_or("tcp")
                    )
                })
                .unwrap_or_default();
            let _ = writeln!(
                out,
                "        <assignment member=\"{}\" icon=\"{}\"{} assigned_at=\"{}\"/>",
                xml_escape(&a.member_name),
                xml_escape(&a.member_icon),
                port_attr,
                xml_escape(&a.assigned_at.to_rfc3339())
            );
        }
        let _ = writeln!(out, "      </assignments>");

        let _ = writeln!(out, "      <notes>");
        for n in &h.notes {
            let author = n
                .member_name
                .clone()
                .unwrap_or_else(|| "anonymous".to_string());
            let _ = writeln!(
                out,
                "        <note author=\"{}\" created_at=\"{}\"><![CDATA[{}]]></note>",
                xml_escape(&author),
                xml_escape(&n.created_at.to_rfc3339()),
                n.note.replace("]]>", "]]]]><![CDATA[>")
            );
        }
        let _ = writeln!(out, "      </notes>");
        let _ = writeln!(out, "    </host>");
    }
    let _ = writeln!(out, "  </hosts>");

    let _ = writeln!(out, "  <scans>");
    for s in &d.scans {
        let _ = writeln!(
            out,
            "    <scan id=\"{}\" type=\"{}\" status=\"{}\" start=\"{}\" targets=\"{}\"/>",
            s.id,
            xml_escape(&s.scan_type),
            xml_escape(&s.status),
            xml_escape(&s.start_time.to_rfc3339()),
            xml_escape(&s.targets)
        );
    }
    let _ = writeln!(out, "  </scans>");

    let _ = writeln!(out, "  <blame_log>");
    for b in &d.blame_log {
        let member = b
            .member_name
            .clone()
            .unwrap_or_else(|| "system".to_string());
        let target = b
            .target_label
            .clone()
            .unwrap_or_else(|| format!("{}#{}", b.target_type, b.target_id));
        let details = b.details.clone().unwrap_or_default();
        let _ = writeln!(
            out,
            "    <entry at=\"{}\" member=\"{}\" action=\"{}\" target=\"{}\" details=\"{}\"/>",
            xml_escape(&b.created_at.to_rfc3339()),
            xml_escape(&member),
            xml_escape(&b.action),
            xml_escape(&target),
            xml_escape(&details)
        );
    }
    let _ = writeln!(out, "  </blame_log>");

    let _ = writeln!(out, "</portherald_export>");
    out
}

fn render_txt(d: &FullExport) -> String {
    let mut out = String::new();
    let _ = writeln!(out, "Port Herald Export");
    let _ = writeln!(out, "Exported: {}", d.exported_at);
    let _ = writeln!(out, "{}", "=".repeat(70));

    let _ = writeln!(out, "\nNETWORKS ({})", d.networks.len());
    for n in &d.networks {
        let _ = writeln!(out, "  - {} (id={})", n.cidr, n.id);
    }

    let _ = writeln!(out, "\nTEAM ({})", d.members.len());
    for m in &d.members {
        let _ = writeln!(out, "  {} {} (id={})", m.icon, m.name, m.id);
    }

    let _ = writeln!(out, "\nHOSTS ({})", d.hosts.len());
    for h in &d.hosts {
        let _ = writeln!(out, "\n{}", "-".repeat(70));
        let _ = writeln!(
            out,
            "{} ({})",
            h.host.ip_address,
            h.host.hostname.clone().unwrap_or_else(|| "-".into())
        );
        let _ = writeln!(
            out,
            "  OS:     {}",
            h.host.os.clone().unwrap_or_else(|| "unknown".into())
        );
        let _ = writeln!(
            out,
            "  Status: {} / {}",
            h.host.status, h.host.investigation_status
        );

        if !h.assignments.is_empty() {
            let _ = write!(out, "  Team:   ");
            for a in &h.assignments {
                let port = a.port_number.map(|n| format!(":{}", n)).unwrap_or_default();
                let _ = write!(out, "{} {}{}  ", a.member_icon, a.member_name, port);
            }
            let _ = writeln!(out);
        }

        if !h.ports.is_empty() {
            let _ = writeln!(out, "  Ports:");
            for pws in &h.ports {
                let p = &pws.port;
                let svc = p.service.clone().unwrap_or_default();
                let prod = p.product.clone().unwrap_or_default();
                let ver = p.version.clone().unwrap_or_default();
                let _ = writeln!(
                    out,
                    "    {}/{} [{}] {} {} {}",
                    p.port_number, p.protocol, p.state, svc, prod, ver
                );
                for s in &pws.scripts {
                    let _ = writeln!(out, "      [{}] {}", s.script_name, s.output.trim());
                }
            }
        }

        if !h.notes.is_empty() {
            let _ = writeln!(out, "  Notes:");
            for n in &h.notes {
                let author = n.member_name.clone().unwrap_or_else(|| "anon".to_string());
                let _ = writeln!(
                    out,
                    "    [{}] {} - {}",
                    n.created_at.to_rfc3339(),
                    author,
                    n.note
                );
            }
        }
    }

    let _ = writeln!(out, "\n{}", "=".repeat(70));
    let _ = writeln!(out, "BLAME LOG ({})", d.blame_log.len());
    for b in &d.blame_log {
        let member = b
            .member_name
            .clone()
            .unwrap_or_else(|| "system".to_string());
        let target = b
            .target_label
            .clone()
            .unwrap_or_else(|| format!("{}#{}", b.target_type, b.target_id));
        let details = b
            .details
            .clone()
            .map(|s| format!(" ({})", s))
            .unwrap_or_default();
        let _ = writeln!(
            out,
            "  [{}] {} {} {}{}",
            b.created_at.to_rfc3339(),
            member,
            b.action,
            target,
            details
        );
    }

    out
}

fn render_notes_txt(
    notes: &[HostNote],
    host_map: &std::collections::HashMap<i64, String>,
) -> String {
    let mut out = String::new();
    let _ = writeln!(out, "Port Herald Notes Export");
    let _ = writeln!(out, "Exported: {}", chrono::Utc::now().to_rfc3339());
    let _ = writeln!(out, "{}", "=".repeat(70));
    for n in notes {
        let host = host_map
            .get(&n.host_id)
            .cloned()
            .unwrap_or_else(|| format!("host#{}", n.host_id));
        let author = n.member_name.clone().unwrap_or_else(|| "anon".to_string());
        let _ = writeln!(
            out,
            "\n[{}] {} on {}",
            n.created_at.to_rfc3339(),
            author,
            host
        );
        let _ = writeln!(out, "{}", n.note);
    }
    out
}

fn render_notes_xml(
    notes: &[HostNote],
    host_map: &std::collections::HashMap<i64, String>,
) -> String {
    let mut out = String::new();
    out.push_str("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<notes>\n");
    for n in notes {
        let host = host_map
            .get(&n.host_id)
            .cloned()
            .unwrap_or_else(|| format!("host#{}", n.host_id));
        let author = n.member_name.clone().unwrap_or_else(|| "anon".to_string());
        let _ = writeln!(
            out,
            "  <note host=\"{}\" author=\"{}\" created_at=\"{}\"><![CDATA[{}]]></note>",
            xml_escape(&host),
            xml_escape(&author),
            xml_escape(&n.created_at.to_rfc3339()),
            n.note.replace("]]>", "]]]]><![CDATA[>")
        );
    }
    out.push_str("</notes>\n");
    out
}
