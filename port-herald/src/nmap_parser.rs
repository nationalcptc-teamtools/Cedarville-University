use crate::db;
use crate::models::*;
use anyhow::{Context, Result};
use chrono::Utc;
use quick_xml::events::Event;
use quick_xml::Reader;
use sqlx::SqlitePool;

pub async fn parse_and_import_nmap_xml(
    pool: &SqlitePool,
    xml_content: &str,
) -> Result<ImportStats> {
    let mut reader = Reader::from_str(xml_content);
    reader.trim_text(true);

    let mut buf = Vec::new();
    let mut stats = ImportStats::default();

    let mut current_host: Option<HostBuilder> = None;
    let mut current_port: Option<PortBuilder> = None;
    let mut in_host = false;
    let mut in_port = false;

    log::info!("Starting XML parse, content length: {}", xml_content.len());

    loop {
        match reader.read_event_into(&mut buf) {
            Ok(Event::Start(ref e)) | Ok(Event::Empty(ref e)) => match e.name().as_ref() {
                b"host" => {
                    in_host = true;
                    current_host = Some(HostBuilder::new());
                    log::debug!("Starting new host");
                }
                b"status" if in_host => {
                    if let Some(ref mut host) = current_host {
                        for attr in e.attributes().flatten() {
                            if attr.key.as_ref() == b"state" {
                                host.status = String::from_utf8_lossy(&attr.value).to_string();
                                log::debug!("Host status: {}", host.status);
                            }
                        }
                    }
                }
                b"address" if in_host => {
                    if let Some(ref mut host) = current_host {
                        let mut addr = String::new();
                        let mut addr_type = String::new();
                        let mut vendor = None;

                        for attr in e.attributes().flatten() {
                            match attr.key.as_ref() {
                                b"addr" => addr = String::from_utf8_lossy(&attr.value).to_string(),
                                b"addrtype" => {
                                    addr_type = String::from_utf8_lossy(&attr.value).to_string()
                                }
                                b"vendor" => {
                                    vendor = Some(String::from_utf8_lossy(&attr.value).to_string())
                                }
                                _ => {}
                            }
                        }

                        match addr_type.as_str() {
                            "ipv4" | "ipv6" if host.ip_address.is_none() => {
                                host.ip_address = Some(addr);
                                log::debug!("Found IP: {}", host.ip_address.as_ref().unwrap());
                            }
                            "mac" => {
                                host.mac_address = Some(addr);
                                host.vendor = vendor;
                            }
                            _ => {}
                        }
                    }
                }
                b"hostname" if in_host => {
                    if let Some(ref mut host) = current_host {
                        for attr in e.attributes().flatten() {
                            if attr.key.as_ref() == b"name" {
                                host.hostname =
                                    Some(String::from_utf8_lossy(&attr.value).to_string());
                                log::debug!("Host hostname: {:?}", host.hostname);
                            }
                        }
                    }
                }
                b"osmatch" if in_host => {
                    if let Some(ref mut host) = current_host {
                        // osmatch is authoritative — overwrite anything a service hint set.
                        let service_sourced = host.os_source.as_deref() == Some("service");
                        if host.os.is_none() || service_sourced {
                            for attr in e.attributes().flatten() {
                                match attr.key.as_ref() {
                                    b"name" => {
                                        host.os =
                                            Some(String::from_utf8_lossy(&attr.value).to_string());
                                    }
                                    b"accuracy" => {
                                        host.os_accuracy = String::from_utf8_lossy(&attr.value)
                                            .parse::<i32>()
                                            .ok();
                                    }
                                    _ => {}
                                }
                            }
                            host.os_source = Some("osmatch".to_string());
                        }
                    }
                }
                b"port" if in_host => {
                    in_port = true;
                    let mut port = PortBuilder::new();

                    for attr in e.attributes().flatten() {
                        match attr.key.as_ref() {
                            b"portid" => {
                                port.port_number =
                                    String::from_utf8_lossy(&attr.value).parse::<i32>().ok();
                            }
                            b"protocol" => {
                                port.protocol = String::from_utf8_lossy(&attr.value).to_string();
                            }
                            _ => {}
                        }
                    }

                    log::debug!("Found port: {:?}/{}", port.port_number, port.protocol);
                    current_port = Some(port);
                }
                b"state" if in_port => {
                    if let Some(ref mut port) = current_port {
                        for attr in e.attributes().flatten() {
                            if attr.key.as_ref() == b"state" {
                                port.state = String::from_utf8_lossy(&attr.value).to_string();
                                log::debug!("Port state: {}", port.state);
                            }
                        }
                    }
                }
                b"service" if in_port => {
                    if let Some(ref mut port) = current_port {
                        let mut svc_ostype: Option<String> = None;
                        let mut svc_extra: Option<String> = None;
                        for attr in e.attributes().flatten() {
                            match attr.key.as_ref() {
                                b"name" => {
                                    port.service =
                                        Some(String::from_utf8_lossy(&attr.value).to_string());
                                }
                                b"product" => {
                                    port.product =
                                        Some(String::from_utf8_lossy(&attr.value).to_string());
                                }
                                b"version" => {
                                    port.version =
                                        Some(String::from_utf8_lossy(&attr.value).to_string());
                                }
                                b"extrainfo" => {
                                    let v = String::from_utf8_lossy(&attr.value).to_string();
                                    svc_extra = Some(v.clone());
                                    port.extra_info = Some(v);
                                }
                                b"ostype" => {
                                    svc_ostype =
                                        Some(String::from_utf8_lossy(&attr.value).to_string());
                                }
                                _ => {}
                            }
                        }
                        // Capture OS hints at the host level too, so topology /
                        // host-detail show an OS even when nmap wasn't run with -O.
                        if let Some(ref mut host) = current_host {
                            if svc_ostype.is_some() || svc_extra.is_some() {
                                host.service_os_hints.push((svc_ostype, svc_extra));
                            }
                        }
                        log::debug!(
                            "Service: {:?} {:?} {:?}",
                            port.service,
                            port.product,
                            port.version
                        );
                    }
                }
                b"script" if in_port => {
                    if let Some(ref mut port) = current_port {
                        let mut script_name = String::new();
                        let mut script_output = String::new();

                        for attr in e.attributes().flatten() {
                            match attr.key.as_ref() {
                                b"id" => {
                                    script_name = String::from_utf8_lossy(&attr.value).to_string();
                                }
                                b"output" => {
                                    script_output =
                                        String::from_utf8_lossy(&attr.value).to_string();
                                }
                                _ => {}
                            }
                        }

                        if !script_name.is_empty() {
                            port.scripts.push((script_name, script_output));
                            log::debug!("Added script");
                        }
                    }
                }
                _ => {}
            },
            Ok(Event::End(ref e)) => {
                match e.name().as_ref() {
                    b"host" => {
                        if let Some(mut host_builder) = current_host.take() {
                            log::info!(
                                "Processing host: IP={:?}, hostname={:?}, status={}",
                                host_builder.ip_address,
                                host_builder.hostname,
                                host_builder.status
                            );

                            // Resolve service-level OS hints into a single value,
                            // but don't overwrite an osmatch-sourced OS.
                            if host_builder.os_source.as_deref() != Some("osmatch") {
                                if let Some(best) = best_service_os(&host_builder.service_os_hints)
                                {
                                    host_builder.os = Some(best);
                                    host_builder.os_source = Some("service".to_string());
                                }
                            }

                            if let Some(ip) = host_builder.ip_address {
                                // Determine network
                                let network_id = if let Ok(network_cidr) = determine_network(&ip) {
                                    db::get_or_create_network(pool, &network_cidr).await.ok()
                                } else {
                                    None
                                };

                                let host = Host {
                                    id: 0,
                                    ip_address: ip.clone(),
                                    hostname: host_builder.hostname,
                                    mac_address: host_builder.mac_address,
                                    vendor: host_builder.vendor,
                                    os: host_builder.os,
                                    os_accuracy: host_builder.os_accuracy,
                                    status: host_builder.status,
                                    first_seen: Utc::now(),
                                    last_seen: Utc::now(),
                                    network_id,
                                    investigation_status: "untouched".to_string(),
                                };

                                match db::upsert_host(pool, &host).await {
                                    Ok(host_id) => {
                                        stats.hosts_imported += 1;
                                        log::info!("✅ Imported host: {} (ID: {})", ip, host_id);

                                        for port_builder in host_builder.ports {
                                            if let Some(port_number) = port_builder.port_number {
                                                let port = Port {
                                                    id: 0,
                                                    host_id,
                                                    port_number,
                                                    protocol: port_builder.protocol,
                                                    state: port_builder.state,
                                                    service: port_builder.service,
                                                    version: port_builder.version,
                                                    product: port_builder.product,
                                                    extra_info: port_builder.extra_info,
                                                    first_seen: Utc::now(),
                                                    last_seen: Utc::now(),
                                                };

                                                if let Ok(port_id) =
                                                    db::upsert_port(pool, &port).await
                                                {
                                                    stats.ports_imported += 1;
                                                    log::debug!(
                                                        "  ✅ Imported port: {}/{}",
                                                        port_number,
                                                        port.protocol
                                                    );

                                                    for (script_name, script_output) in
                                                        port_builder.scripts
                                                    {
                                                        let script = ScriptResult {
                                                            id: 0,
                                                            port_id,
                                                            script_name,
                                                            output: script_output,
                                                            created_at: Utc::now(),
                                                        };

                                                        if db::insert_script_result(pool, &script)
                                                            .await
                                                            .is_ok()
                                                        {
                                                            stats.scripts_imported += 1;
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    Err(e) => {
                                        log::error!("❌ Failed to insert host {}: {}", ip, e);
                                    }
                                }
                            } else {
                                log::warn!("Skipping host with no IP address");
                            }
                        }
                        in_host = false;
                    }
                    b"port" => {
                        if let (Some(ref mut host), Some(port)) =
                            (&mut current_host, current_port.take())
                        {
                            host.ports.push(port);
                        }
                        in_port = false;
                    }
                    _ => {}
                }
            }
            Ok(Event::Eof) => break,
            Err(e) => {
                log::error!("XML parse error: {:?}", e);
                return Err(anyhow::anyhow!("XML parse error: {:?}", e));
            }
            _ => {}
        }
        buf.clear();
    }

    log::info!(
        "✅ Import complete: {} hosts, {} ports, {} scripts",
        stats.hosts_imported,
        stats.ports_imported,
        stats.scripts_imported
    );
    Ok(stats)
}

struct HostBuilder {
    ip_address: Option<String>,
    hostname: Option<String>,
    mac_address: Option<String>,
    vendor: Option<String>,
    os: Option<String>,
    os_accuracy: Option<i32>,
    os_source: Option<String>, // "osmatch" | "service"
    /// Service-level OS hints collected during parsing; resolved to the
    /// single most-specific guess when the host element closes.
    service_os_hints: Vec<(Option<String>, Option<String>)>, // (ostype, extrainfo)
    status: String,
    ports: Vec<PortBuilder>,
}

impl HostBuilder {
    fn new() -> Self {
        Self {
            ip_address: None,
            hostname: None,
            mac_address: None,
            vendor: None,
            os: None,
            os_accuracy: None,
            os_source: None,
            service_os_hints: Vec::new(),
            status: "unknown".to_string(),
            ports: Vec::new(),
        }
    }
}

/// Build a human-readable OS string from a service element's `ostype` and
/// `extrainfo` attributes. Returns None if neither carries useful info.
///
/// Examples:
///   ostype="Linux",  extrainfo="Ubuntu Linux; protocol 2.0" -> "Linux (Ubuntu)"
///   ostype="Linux",  extrainfo="(Debian)"                   -> "Linux (Debian)"
///   ostype="Unix",   extrainfo=None                         -> "Unix"
///   ostype=None,     extrainfo="(Debian)"                   -> "Linux (Debian)"
fn infer_os_from_service(ostype: &Option<String>, extrainfo: &Option<String>) -> Option<String> {
    let distro = extrainfo.as_ref().and_then(|s| {
        let lower = s.to_lowercase();
        let hits = [
            "ubuntu", "debian", "centos", "redhat", "rhel", "fedora", "alpine", "arch", "kali",
            "gentoo", "suse", "opensuse", "freebsd", "openbsd", "netbsd", "windows",
        ];
        for name in hits.iter() {
            if lower.contains(name) {
                let proper = {
                    let mut c = name.chars();
                    match c.next() {
                        Some(f) => f.to_uppercase().chain(c).collect::<String>(),
                        None => String::new(),
                    }
                };
                return Some(proper);
            }
        }
        None
    });

    match (ostype.as_deref(), distro) {
        (Some(ot), Some(d)) if !ot.is_empty() => Some(format!("{} ({})", ot, d)),
        (Some(ot), None) if !ot.is_empty() => Some(ot.to_string()),
        (None, Some(d)) => Some(format!("Linux ({})", d)), // extrainfo-only Linux distros
        _ => None,
    }
}

/// Score a service-level OS inference by how specific it is, and pick the
/// highest-scoring hint from a list.
///
///   has distro:                              +2
///   explicit ostype attribute present:       +1  (direct Nmap determination, beats
///                                                 distro-only inference like Apache's "(Debian)")
///   ostype == Linux | Windows | *BSD:        +1  (anything more specific than "Unix")
///   ostype == Unix:                          +0
///   nothing:                                 None
fn best_service_os(hints: &[(Option<String>, Option<String>)]) -> Option<String> {
    hints
        .iter()
        .filter_map(|(ot, ex)| {
            let rendered = infer_os_from_service(ot, ex)?;
            let mut score = 0;
            if rendered.contains('(') {
                score += 2;
            }
            if ot.as_ref().map(|s| !s.is_empty()).unwrap_or(false) {
                score += 1;
            }
            let lower = rendered.to_lowercase();
            if lower.starts_with("linux")
                || lower.starts_with("windows")
                || lower.contains("bsd")
                || lower.starts_with("solaris")
            {
                score += 1;
            }
            Some((score, rendered))
        })
        .max_by_key(|(score, _)| *score)
        .map(|(_, s)| s)
}

struct PortBuilder {
    port_number: Option<i32>,
    protocol: String,
    state: String,
    service: Option<String>,
    version: Option<String>,
    product: Option<String>,
    extra_info: Option<String>,
    scripts: Vec<(String, String)>,
}

impl PortBuilder {
    fn new() -> Self {
        Self {
            port_number: None,
            protocol: "tcp".to_string(),
            state: "unknown".to_string(),
            service: None,
            version: None,
            product: None,
            extra_info: None,
            scripts: Vec::new(),
        }
    }
}

#[derive(Default, Debug)]
pub struct ImportStats {
    pub hosts_imported: u32,
    pub ports_imported: u32,
    pub scripts_imported: u32,
}

fn determine_network(ip: &str) -> Result<String> {
    use std::net::IpAddr;

    let addr: IpAddr = ip.parse().context("Invalid IP address")?;

    match addr {
        IpAddr::V4(ipv4) => {
            let octets = ipv4.octets();
            // Try to determine the network class
            if octets[0] == 10 {
                Ok(format!("10.{}.{}.0/24", octets[1], octets[2]))
            } else if octets[0] == 172 && (octets[1] >= 16 && octets[1] <= 31) {
                Ok(format!("172.{}.{}.0/24", octets[1], octets[2]))
            } else if octets[0] == 192 && octets[1] == 168 {
                Ok(format!("192.168.{}.0/24", octets[2]))
            } else {
                Ok(format!("{}.{}.{}.0/24", octets[0], octets[1], octets[2]))
            }
        }
        IpAddr::V6(_) => Ok(format!("{}/64", addr)),
    }
}
