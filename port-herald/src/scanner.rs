use crate::models::*;
use anyhow::Result;
use chrono::{DateTime, Utc};
use regex::Regex;
use sqlx::SqlitePool;
use std::collections::HashMap;
use std::process::Stdio;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::process::Command;
use tokio::sync::RwLock;
use uuid::Uuid;

// ── Scan Manager ────────────────────────────────────────────────────────

pub struct ScanManager {
    active_scans: HashMap<String, Arc<RwLock<ScanState>>>,
    cancel_flags: HashMap<String, Arc<AtomicBool>>,
}

pub struct ScanState {
    pub id: String,
    pub config: ScanConfig,
    pub phase: ScanPhase,
    pub phase_percent: f32,   // 0-100 within the current phase
    pub overall_percent: f32, // 0-100 across the full pipeline
    pub hosts_discovered: Vec<String>,
    pub ports_discovered: u32,
    pub logs: Vec<String>,
    pub started_at: DateTime<Utc>,
    pub finished_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, PartialEq)]
pub enum ScanPhase {
    Initializing,
    HostDiscovery,
    CommonPortScan,
    AllPortScan,
    ServiceDetection,
    ScriptScan,
    Complete,
    Failed(String),
    Cancelled,
}

impl ScanPhase {
    pub fn is_terminal(&self) -> bool {
        matches!(self, Self::Complete | Self::Failed(_) | Self::Cancelled)
    }
    pub fn label(&self) -> String {
        match self {
            Self::Initializing => "Initializing".into(),
            Self::HostDiscovery => "Host Discovery".into(),
            Self::CommonPortScan => "Common Port Scan".into(),
            Self::AllPortScan => "All-Port Scan".into(),
            Self::ServiceDetection => "Service Detection".into(),
            Self::ScriptScan => "Script Scan".into(),
            Self::Complete => "Complete".into(),
            Self::Failed(e) => format!("Failed: {}", e),
            Self::Cancelled => "Cancelled".into(),
        }
    }
    /// Window of the overall progress bar this phase occupies.
    pub fn weight(&self) -> (f32, f32) {
        match self {
            Self::Initializing => (0.0, 2.0),
            Self::HostDiscovery => (2.0, 13.0),     // 2-15
            Self::CommonPortScan => (15.0, 15.0),   // 15-30
            Self::AllPortScan => (30.0, 45.0),      // 30-75
            Self::ServiceDetection => (75.0, 15.0), // 75-90
            Self::ScriptScan => (90.0, 10.0),       // 90-100
            Self::Complete => (100.0, 0.0),
            Self::Failed(_) | Self::Cancelled => (0.0, 0.0),
        }
    }
}

impl ScanManager {
    pub fn new() -> Self {
        Self {
            active_scans: HashMap::new(),
            cancel_flags: HashMap::new(),
        }
    }

    pub async fn start_scan(&mut self, config: ScanConfig, pool: SqlitePool) -> Result<String> {
        let scan_id = Uuid::new_v4().to_string();
        let now = Utc::now();

        let state = Arc::new(RwLock::new(ScanState {
            id: scan_id.clone(),
            config: config.clone(),
            phase: ScanPhase::Initializing,
            phase_percent: 0.0,
            overall_percent: 0.0,
            hosts_discovered: Vec::new(),
            ports_discovered: 0,
            logs: Vec::new(),
            started_at: now,
            finished_at: None,
        }));

        let cancel = Arc::new(AtomicBool::new(false));
        self.active_scans.insert(scan_id.clone(), state.clone());
        self.cancel_flags.insert(scan_id.clone(), cancel.clone());

        // Persist the scan session so it survives server restart and shows up
        // in /api/scans (the DB-backed scan history). Fire-and-forget: if the
        // write fails we still proceed with the in-memory session.
        let scan_type_str = config.scan_type.to_nmap_flag().to_string();
        let targets_str = config.targets.join(",");
        let args_str = serde_json::to_string(&config).unwrap_or_default();
        if let Err(e) =
            crate::db::create_scan(&pool, &scan_id, &scan_type_str, &targets_str, &args_str).await
        {
            log::warn!("Failed to persist scan session {}: {}", scan_id, e);
        }

        let state_task = state.clone();
        let cancel_task = cancel.clone();
        let pool_task = pool.clone();
        let scan_id_task = scan_id.clone();
        tokio::spawn(async move {
            let result = execute_scan(
                state_task.clone(),
                config,
                pool_task.clone(),
                cancel_task.clone(),
            )
            .await;

            let (final_status, final_phase, final_log, hosts_count, ports_count);
            {
                let mut s = state_task.write().await;
                s.finished_at = Some(Utc::now());
                if cancel_task.load(Ordering::Relaxed) {
                    s.phase = ScanPhase::Cancelled;
                    s.logs.push("[!] Scan cancelled by user".to_string());
                    final_status = "cancelled";
                } else if let Err(e) = result {
                    s.phase = ScanPhase::Failed(e.to_string());
                    s.logs.push(format!("[!] Scan failed: {}", e));
                    log::error!("Scan {} failed: {}", s.id, e);
                    final_status = "failed";
                } else {
                    s.phase = ScanPhase::Complete;
                    s.overall_percent = 100.0;
                    s.phase_percent = 100.0;
                    s.logs.push("[✓] Scan complete".to_string());
                    final_status = "complete";
                }
                final_phase = s.phase.clone();
                final_log = s.logs.len();
                hosts_count = s.hosts_discovered.len() as i32;
                ports_count = s.ports_discovered as i32;
            }
            let _ = (final_phase, final_log); // reserved for future audit logging

            if let Err(e) = crate::db::finalize_scan(
                &pool_task,
                &scan_id_task,
                final_status,
                hosts_count,
                ports_count,
            )
            .await
            {
                log::warn!("Failed to finalize scan session {}: {}", scan_id_task, e);
            }
        });

        Ok(scan_id)
    }

    pub async fn cancel_scan(&self, scan_id: &str) -> bool {
        if let Some(flag) = self.cancel_flags.get(scan_id) {
            flag.store(true, Ordering::Relaxed);
            true
        } else {
            false
        }
    }

    pub async fn get_scan_status(&self, scan_id: &str) -> Option<ActiveScan> {
        let state = self.active_scans.get(scan_id)?;
        let s = state.read().await;
        let cancel = self
            .cancel_flags
            .get(scan_id)
            .map(|f| f.load(Ordering::Relaxed))
            .unwrap_or(false);
        Some(ActiveScan::from_state(&s, cancel))
    }

    pub async fn list_active(&self) -> Vec<ActiveScan> {
        let mut out = Vec::new();
        for (id, state) in &self.active_scans {
            let s = state.read().await;
            let cancel = self
                .cancel_flags
                .get(id)
                .map(|f| f.load(Ordering::Relaxed))
                .unwrap_or(false);
            out.push(ActiveScan::from_state(&s, cancel));
        }
        out.sort_by_key(|s| std::cmp::Reverse(s.started_at));
        out
    }

    pub async fn get_logs(&self, scan_id: &str, since: usize) -> Option<ScanLogSlice> {
        let state = self.active_scans.get(scan_id)?;
        let s = state.read().await;
        let total = s.logs.len();
        let from = since.min(total);
        let slice = s.logs[from..].to_vec();
        Some(ScanLogSlice {
            scan_id: scan_id.to_string(),
            total,
            offset: from,
            lines: slice,
        })
    }

    /// Prune terminal scans older than the given age.
    pub async fn prune(&mut self, keep_recent_secs: i64) {
        let cutoff = Utc::now() - chrono::Duration::seconds(keep_recent_secs);
        let mut to_remove = Vec::new();
        for (id, state) in &self.active_scans {
            let s = state.read().await;
            if s.phase.is_terminal() {
                if let Some(finished) = s.finished_at {
                    if finished < cutoff {
                        to_remove.push(id.clone());
                    }
                }
            }
        }
        for id in to_remove {
            self.active_scans.remove(&id);
            self.cancel_flags.remove(&id);
        }
    }
}

// ── Pipeline ────────────────────────────────────────────────────────────

async fn execute_scan(
    state: Arc<RwLock<ScanState>>,
    config: ScanConfig,
    pool: SqlitePool,
    cancel: Arc<AtomicBool>,
) -> Result<()> {
    macro_rules! check_cancel {
        () => {
            if cancel.load(Ordering::Relaxed) {
                return Err(anyhow::anyhow!("cancelled"));
            }
        };
    }

    // ── Phase 1: Host Discovery ──
    set_phase(
        &state,
        ScanPhase::HostDiscovery,
        "Starting host discovery...",
    )
    .await;
    check_cancel!();

    let discovered_hosts = {
        let has_mass = has_masscan().await;
        let primary = if has_mass {
            append_log(&state, "Using masscan for initial discovery").await;
            discover_hosts_masscan(&state, &config, cancel.clone()).await
        } else {
            append_log(&state, "Using nmap -sn for initial discovery").await;
            discover_hosts_nmap(&state, &config, cancel.clone()).await
        };

        match primary {
            Ok(hosts) if !hosts.is_empty() => hosts,
            Ok(_empty) if has_mass => {
                // Masscan returned 0 open ports, but the host may still be up and
                // simply filtering every TCP port. Fall back to nmap -sn (ICMP /
                // ARP / TCP-SYN-80 / TCP-ACK-443 probes) to pick up pingable hosts.
                append_log(
                    &state,
                    "[!] masscan found 0 open ports; falling back to nmap -sn ping sweep...",
                )
                .await;
                check_cancel!();
                let fallback = discover_hosts_nmap(&state, &config, cancel.clone()).await?;
                if fallback.is_empty() {
                    append_log(
                        &state,
                        "[!] nmap -sn also found no live hosts \u{2014} target(s) may be fully filtered or offline",
                    )
                    .await;
                }
                fallback
            }
            Ok(empty) => empty,
            Err(e) if has_mass => {
                // Masscan errored out (permissions, missing default interface, etc).
                // Try the pure-nmap path so the pipeline still produces a result.
                append_log(
                    &state,
                    &format!(
                        "[!] masscan error ({}); falling back to nmap -sn ping sweep...",
                        e
                    ),
                )
                .await;
                check_cancel!();
                discover_hosts_nmap(&state, &config, cancel.clone()).await?
            }
            Err(e) => return Err(e),
        }
    };

    {
        let mut s = state.write().await;
        s.hosts_discovered = discovered_hosts.clone();
        s.phase_percent = 100.0;
        s.overall_percent = overall_for(&s.phase, 100.0);
        s.logs
            .push(format!("[✓] Discovered {} hosts", discovered_hosts.len()));
    }

    if discovered_hosts.is_empty() {
        return Ok(());
    }
    check_cancel!();

    // ── Phase 2: Common Port Scan ──
    set_phase(
        &state,
        ScanPhase::CommonPortScan,
        "Scanning top 1000 ports...",
    )
    .await;
    let common_ports_file =
        scan_common_ports(&state, &config, &discovered_hosts, cancel.clone()).await?;
    auto_ingest(&pool, &state, &common_ports_file, "Common port scan").await;
    update_counts_from_xml(&pool, &state, &common_ports_file).await;
    check_cancel!();

    // ── Phase 3a + 3b: service detection on common ports (parallel with all-port scan) ──
    let common_svc_file = format!("/tmp/nmap_services_common_{}.xml", Uuid::new_v4());
    let service_handle = {
        let state = state.clone();
        let config = config.clone();
        let common_ports = common_ports_file.clone();
        let cancel = cancel.clone();
        let out = common_svc_file.clone();
        tokio::spawn(async move {
            service_detection(&state, &config, &common_ports, &out, cancel).await
        })
    };

    // ── Phase 4: All-Port Scan (concurrent with common-port service detection) ──
    set_phase(
        &state,
        ScanPhase::AllPortScan,
        "Scanning all 65535 ports (service detection running in parallel)...",
    )
    .await;
    let all_ports_file = scan_all_ports(&state, &config, &discovered_hosts, cancel.clone()).await?;
    auto_ingest(&pool, &state, &all_ports_file, "All-port scan").await;
    update_counts_from_xml(&pool, &state, &all_ports_file).await;
    check_cancel!();

    // Finish service detection. The handle returns Result<Result<()>, JoinError>:
    // outer = tokio task join, inner = whatever service_detection returned.
    match service_handle.await {
        Ok(Ok(())) => {}
        Ok(Err(e)) => {
            append_log(
                &state,
                &format!("[!] Service detection (common) failed: {}", e),
            )
            .await;
        }
        Err(e) => {
            append_log(
                &state,
                &format!("[!] Service detection (common) task join error: {}", e),
            )
            .await;
        }
    }
    auto_ingest(
        &pool,
        &state,
        &common_svc_file,
        "Service detection (common)",
    )
    .await;

    // ── Phase 5: Service Detection on newly-discovered ports ──
    set_phase(
        &state,
        ScanPhase::ServiceDetection,
        "Detecting services on new ports...",
    )
    .await;
    let final_svc = format!("/tmp/nmap_services_final_{}.xml", Uuid::new_v4());
    service_detection(&state, &config, &all_ports_file, &final_svc, cancel.clone()).await?;
    auto_ingest(&pool, &state, &final_svc, "Service detection (final)").await;
    update_counts_from_xml(&pool, &state, &final_svc).await;
    check_cancel!();

    // ── Phase 6: NSE scripts (if enabled) ──
    //
    // NSE scripts (-sC) are opportunistically folded into the two prior
    // service-detection runs when `script_scan` is set, so the heavy lifting
    // is already on disk by the time we get here. This phase is a cosmetic
    // marker so the UI progress bar completes and the user sees the step in
    // the phase sequence.
    if config.script_scan {
        set_phase(
            &state,
            ScanPhase::ScriptScan,
            "NSE scripts (ran in-line with service detection)",
        )
        .await;
        {
            let mut s = state.write().await;
            s.phase_percent = 100.0;
            s.overall_percent = overall_for(&s.phase, 100.0);
        }
    }

    Ok(())
}

async fn set_phase(state: &Arc<RwLock<ScanState>>, phase: ScanPhase, msg: &str) {
    let mut s = state.write().await;
    s.phase = phase;
    s.phase_percent = 0.0;
    s.overall_percent = overall_for(&s.phase, 0.0);
    s.logs.push(format!("[→] {}", msg));
}

async fn append_log(state: &Arc<RwLock<ScanState>>, msg: &str) {
    state.write().await.logs.push(msg.to_string());
}

fn overall_for(phase: &ScanPhase, phase_pct: f32) -> f32 {
    let (start, weight) = phase.weight();
    (start + weight * phase_pct.clamp(0.0, 100.0) / 100.0).clamp(0.0, 100.0)
}

/// Parse XML output of a completed phase and import it into the database.
async fn auto_ingest(
    pool: &SqlitePool,
    state: &Arc<RwLock<ScanState>>,
    xml_path: &str,
    label: &str,
) {
    if let Ok(xml) = tokio::fs::read_to_string(xml_path).await {
        match crate::nmap_parser::parse_and_import_nmap_xml(pool, &xml).await {
            Ok(stats) => {
                append_log(
                    state,
                    &format!(
                        "[↓] {}: imported {} hosts, {} ports, {} scripts",
                        label, stats.hosts_imported, stats.ports_imported, stats.scripts_imported
                    ),
                )
                .await;
            }
            Err(e) => {
                append_log(state, &format!("[!] {} import failed: {}", label, e)).await;
            }
        }
    }
}

/// Count ports in XML output and update state counters, also pushing the
/// running totals to the persisted scan session.
async fn update_counts_from_xml(pool: &SqlitePool, state: &Arc<RwLock<ScanState>>, xml_path: &str) {
    if let Ok(xml) = tokio::fs::read_to_string(xml_path).await {
        let ports = xml.matches("<port ").count() as u32;
        let hosts: std::collections::HashSet<String> = {
            use quick_xml::events::Event;
            use quick_xml::Reader;
            let mut reader = Reader::from_str(&xml);
            reader.trim_text(true);
            let mut buf = Vec::new();
            let mut set = std::collections::HashSet::new();
            let mut in_host = false;
            loop {
                match reader.read_event_into(&mut buf) {
                    Ok(Event::Start(ref e)) | Ok(Event::Empty(ref e)) => match e.name().as_ref() {
                        b"host" => {
                            in_host = true;
                        }
                        b"address" if in_host => {
                            for attr in e.attributes().flatten() {
                                if attr.key.as_ref() == b"addr" {
                                    set.insert(String::from_utf8_lossy(&attr.value).to_string());
                                }
                            }
                        }
                        _ => {}
                    },
                    Ok(Event::End(ref e)) if e.name().as_ref() == b"host" => in_host = false,
                    Ok(Event::Eof) => break,
                    Err(_) => break,
                    _ => {}
                }
                buf.clear();
            }
            set
        };
        let (scan_uuid, hosts_count, ports_count) = {
            let mut s = state.write().await;
            s.ports_discovered = s.ports_discovered.max(ports);
            if hosts.len() > s.hosts_discovered.len() {
                s.hosts_discovered = hosts.into_iter().collect();
            }
            (
                s.id.clone(),
                s.hosts_discovered.len() as i32,
                s.ports_discovered as i32,
            )
        };
        if let Err(e) =
            crate::db::touch_scan_counters(pool, &scan_uuid, hosts_count, ports_count).await
        {
            log::debug!("touch_scan_counters failed for {}: {}", scan_uuid, e);
        }
    }
}

// ── Discovery backends ──────────────────────────────────────────────────

async fn has_masscan() -> bool {
    Command::new("which")
        .arg("masscan")
        .output()
        .await
        .map(|o| o.status.success())
        .unwrap_or(false)
}

async fn discover_hosts_masscan(
    state: &Arc<RwLock<ScanState>>,
    config: &ScanConfig,
    cancel: Arc<AtomicBool>,
) -> Result<Vec<String>> {
    let output_file = format!("/tmp/masscan_{}.txt", Uuid::new_v4());

    let mut args = vec![
        "-p1-65535".to_string(),
        "--rate".to_string(),
        config.max_rate.unwrap_or(1000).to_string(),
        "-oL".to_string(),
        output_file.clone(),
    ];
    for target in &config.targets {
        args.push(target.clone());
    }
    for excluded in &config.excluded_targets {
        args.push("--exclude".to_string());
        args.push(excluded.clone());
    }

    run_cmd(state, "masscan", args, cancel).await?;

    let content = tokio::fs::read_to_string(&output_file)
        .await
        .unwrap_or_default();
    let hosts: std::collections::HashSet<String> = content
        .lines()
        .filter(|line| line.starts_with("open"))
        .filter_map(|line| line.split_whitespace().nth(3).map(String::from))
        .collect();

    Ok(hosts.into_iter().collect())
}

async fn discover_hosts_nmap(
    state: &Arc<RwLock<ScanState>>,
    config: &ScanConfig,
    cancel: Arc<AtomicBool>,
) -> Result<Vec<String>> {
    let output_file = format!("/tmp/nmap_discovery_{}.xml", Uuid::new_v4());

    let mut args = vec!["-sn".to_string(), "-oX".to_string(), output_file.clone()];
    args.push(config.timing_template.to_nmap_flag().to_string());
    for target in &config.targets {
        args.push(target.clone());
    }
    for excluded in &config.excluded_targets {
        args.push("--exclude".to_string());
        args.push(excluded.clone());
    }

    run_cmd(state, "nmap", args, cancel).await?;

    let content = tokio::fs::read_to_string(&output_file)
        .await
        .unwrap_or_default();
    parse_live_hosts_from_xml(&content)
}

async fn scan_common_ports(
    state: &Arc<RwLock<ScanState>>,
    config: &ScanConfig,
    hosts: &[String],
    cancel: Arc<AtomicBool>,
) -> Result<String> {
    let output_file = format!("/tmp/nmap_common_{}.xml", Uuid::new_v4());
    let mut args = vec![
        config.scan_type.to_nmap_flag().to_string(),
        "--top-ports".to_string(),
        "1000".to_string(),
        "-oX".to_string(),
        output_file.clone(),
    ];
    args.push(config.timing_template.to_nmap_flag().to_string());
    if config.evasion_enabled {
        if let Some(sp) = config.source_port {
            args.push("--source-port".to_string());
            args.push(sp.to_string());
        }
        args.push("-f".to_string());
    }
    for dns in &config.dns_servers {
        args.push("--dns-servers".to_string());
        args.push(dns.clone());
    }
    for excluded in &config.excluded_targets {
        args.push("--exclude".to_string());
        args.push(excluded.clone());
    }
    for host in hosts {
        args.push(host.clone());
    }

    run_cmd(state, "nmap", args, cancel).await?;
    Ok(output_file)
}

async fn scan_all_ports(
    state: &Arc<RwLock<ScanState>>,
    config: &ScanConfig,
    hosts: &[String],
    cancel: Arc<AtomicBool>,
) -> Result<String> {
    let output_file = format!("/tmp/nmap_allports_{}.xml", Uuid::new_v4());
    let mut args = vec![
        config.scan_type.to_nmap_flag().to_string(),
        "-p-".to_string(),
        "-oX".to_string(),
        output_file.clone(),
    ];
    args.push(config.timing_template.to_nmap_flag().to_string());
    if config.evasion_enabled {
        if let Some(sp) = config.source_port {
            args.push("--source-port".to_string());
            args.push(sp.to_string());
        }
        args.push("-f".to_string());
    }
    if config.udp_scan {
        args.push("-sU".to_string());
    }
    for dns in &config.dns_servers {
        args.push("--dns-servers".to_string());
        args.push(dns.clone());
    }
    for excluded in &config.excluded_targets {
        args.push("--exclude".to_string());
        args.push(excluded.clone());
    }
    for host in hosts {
        args.push(host.clone());
    }

    run_cmd(state, "nmap", args, cancel).await?;
    Ok(output_file)
}

async fn service_detection(
    state: &Arc<RwLock<ScanState>>,
    config: &ScanConfig,
    input_file: &str,
    output_file: &str,
    cancel: Arc<AtomicBool>,
) -> Result<()> {
    // Extract (hosts, open_ports) from the prior-phase XML. We can't just
    // feed the XML to nmap via `-iL` — that flag expects a plain-text target
    // list, and nmap will try to parse every XML tag as a target spec.
    let xml = tokio::fs::read_to_string(input_file)
        .await
        .unwrap_or_default();
    let (hosts, ports) = parse_hosts_and_open_ports(&xml);

    if hosts.is_empty() || ports.is_empty() {
        append_log(
            state,
            "[→] No open ports from prior phase; skipping service detection",
        )
        .await;
        // Write an empty-ish nmaprun so auto_ingest doesn't choke on a missing file.
        let _ = tokio::fs::write(
            output_file,
            r#"<?xml version="1.0"?><nmaprun scanner="port-herald"/>"#,
        )
        .await;
        return Ok(());
    }

    let port_list = ports
        .iter()
        .map(|p| p.to_string())
        .collect::<Vec<_>>()
        .join(",");
    let mut args = vec![
        "-sV".to_string(),
        "-p".to_string(),
        port_list,
        "-oX".to_string(),
        output_file.to_string(),
    ];
    if config.version_detection {
        args.push("--version-intensity".to_string());
        args.push("9".to_string());
    }
    if config.os_detection {
        args.push("-O".to_string());
    }
    if config.script_scan {
        args.push("-sC".to_string());
    }
    args.push(config.timing_template.to_nmap_flag().to_string());
    for excluded in &config.excluded_targets {
        args.push("--exclude".to_string());
        args.push(excluded.clone());
    }
    for h in &hosts {
        args.push(h.clone());
    }

    run_cmd(state, "nmap", args, cancel).await
}

// ── Subprocess runner with live stderr parsing & cancellation ───────────

async fn run_cmd(
    state: &Arc<RwLock<ScanState>>,
    program: &str,
    mut args: Vec<String>,
    cancel: Arc<AtomicBool>,
) -> Result<()> {
    // Inject --stats-every (nmap only) so we get periodic progress on stderr.
    if program == "nmap" && !args.iter().any(|a| a == "--stats-every") {
        args.insert(0, "--stats-every".into());
        args.insert(1, "2s".into());
    }
    // Ensure verbose output (needed for "Discovered open port" messages).
    if program == "nmap" && !args.iter().any(|a| a == "-v" || a == "-vv") {
        args.insert(0, "-v".into());
    }

    let cmdline = format!("{} {}", program, args.join(" "));
    append_log(state, &format!("$ {}", cmdline)).await;
    log::info!("Running: {}", cmdline);

    let mut cmd = Command::new(program);
    cmd.args(&args)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .kill_on_drop(true);

    let mut child = cmd.spawn()?;

    // Spawn stdout reader
    if let Some(stdout) = child.stdout.take() {
        let state = state.clone();
        tokio::spawn(async move {
            let reader = BufReader::new(stdout);
            let mut lines = reader.lines();
            while let Ok(Some(line)) = lines.next_line().await {
                parse_and_record(&state, &line).await;
            }
        });
    }
    // Spawn stderr reader
    if let Some(stderr) = child.stderr.take() {
        let state = state.clone();
        tokio::spawn(async move {
            let reader = BufReader::new(stderr);
            let mut lines = reader.lines();
            while let Ok(Some(line)) = lines.next_line().await {
                parse_and_record(&state, &line).await;
            }
        });
    }

    // Race wait vs cancel
    let status = tokio::select! {
        s = child.wait() => s?,
        _ = wait_for_cancel(cancel.clone()) => {
            let _ = child.kill().await;
            return Err(anyhow::anyhow!("cancelled"));
        }
    };

    if !status.success() && !cancel.load(Ordering::Relaxed) {
        return Err(anyhow::anyhow!("{} exited with status {}", program, status));
    }
    Ok(())
}

async fn wait_for_cancel(flag: Arc<AtomicBool>) {
    loop {
        if flag.load(Ordering::Relaxed) {
            return;
        }
        tokio::time::sleep(std::time::Duration::from_millis(250)).await;
    }
}

// ── Live line parser (progress %, discovered ports) ─────────────────────

async fn parse_and_record(state: &Arc<RwLock<ScanState>>, line: &str) {
    // Nmap progress line: "SYN Stealth Scan Timing: About 23.45% done"
    static PCT_RX: once_cell::sync::Lazy<Regex> =
        once_cell::sync::Lazy::new(|| Regex::new(r"(\d+(?:\.\d+)?)% done").unwrap());
    // Discovered open port line: "Discovered open port 445/tcp on 192.168.1.5"
    static DISCO_RX: once_cell::sync::Lazy<Regex> = once_cell::sync::Lazy::new(|| {
        Regex::new(r"Discovered open port (\d+)/(tcp|udp) on (\S+)").unwrap()
    });

    let trimmed = line.trim_end();
    if trimmed.is_empty() {
        return;
    }

    let mut pct: Option<f32> = None;
    let mut new_port: Option<String> = None;

    if let Some(cap) = PCT_RX.captures(trimmed) {
        pct = cap.get(1).and_then(|m| m.as_str().parse::<f32>().ok());
    }
    if let Some(cap) = DISCO_RX.captures(trimmed) {
        new_port = cap.get(3).map(|m| m.as_str().to_string());
    }

    let mut s = state.write().await;
    s.logs.push(trimmed.to_string());
    // Cap log size to avoid unbounded growth (keep last 5000 lines)
    if s.logs.len() > 5000 {
        let drop = s.logs.len() - 5000;
        s.logs.drain(0..drop);
    }
    if let Some(p) = pct {
        s.phase_percent = p;
        let phase = s.phase.clone();
        s.overall_percent = overall_for(&phase, p);
    }
    if let Some(ip) = new_port {
        s.ports_discovered += 1;
        if !s.hosts_discovered.iter().any(|h| h == &ip) {
            s.hosts_discovered.push(ip);
        }
    }
}

// ── XML helpers ─────────────────────────────────────────────────────────

/// Extract (hosts-with-at-least-one-open-port, unique-open-port-numbers) from
/// an nmap XML document. Used to drive the targeted `-sV -p …` service
/// detection pass instead of blindly re-scanning all 65 535 ports.
fn parse_hosts_and_open_ports(xml: &str) -> (Vec<String>, Vec<u16>) {
    use quick_xml::events::Event;
    use quick_xml::Reader;

    let mut reader = Reader::from_str(xml);
    reader.trim_text(true);
    let mut buf = Vec::new();

    let mut hosts: Vec<String> = Vec::new();
    let mut ports_set = std::collections::BTreeSet::<u16>::new();

    let mut in_host = false;
    let mut in_port = false;
    let mut current_ip: Option<String> = None;
    let mut host_has_open = false;
    let mut this_port: Option<u16> = None;
    let mut this_port_open = false;

    loop {
        match reader.read_event_into(&mut buf) {
            Ok(Event::Start(ref e)) | Ok(Event::Empty(ref e)) => match e.name().as_ref() {
                b"host" => {
                    in_host = true;
                    current_ip = None;
                    host_has_open = false;
                }
                b"address" if in_host => {
                    let mut addr = None;
                    let mut addrtype = None;
                    for attr in e.attributes().flatten() {
                        match attr.key.as_ref() {
                            b"addr" => {
                                addr = Some(String::from_utf8_lossy(&attr.value).to_string())
                            }
                            b"addrtype" => {
                                addrtype = Some(String::from_utf8_lossy(&attr.value).to_string())
                            }
                            _ => {}
                        }
                    }
                    // Prefer the first ipv4/ipv6 record; ignore MAC.
                    if current_ip.is_none()
                        && matches!(addrtype.as_deref(), Some("ipv4") | Some("ipv6"))
                    {
                        current_ip = addr;
                    }
                }
                b"port" if in_host => {
                    in_port = true;
                    this_port = None;
                    this_port_open = false;
                    for attr in e.attributes().flatten() {
                        if attr.key.as_ref() == b"portid" {
                            this_port = String::from_utf8_lossy(&attr.value).parse::<u16>().ok();
                        }
                    }
                }
                b"state" if in_port => {
                    for attr in e.attributes().flatten() {
                        if attr.key.as_ref() == b"state" {
                            let v = String::from_utf8_lossy(&attr.value);
                            if v == "open" || v == "open|filtered" {
                                this_port_open = true;
                            }
                        }
                    }
                }
                _ => {}
            },
            Ok(Event::End(ref e)) => match e.name().as_ref() {
                b"port" => {
                    if this_port_open {
                        if let Some(p) = this_port {
                            ports_set.insert(p);
                            host_has_open = true;
                        }
                    }
                    in_port = false;
                }
                b"host" => {
                    if host_has_open {
                        if let Some(ip) = current_ip.take() {
                            if !hosts.contains(&ip) {
                                hosts.push(ip);
                            }
                        }
                    }
                    in_host = false;
                }
                _ => {}
            },
            Ok(Event::Eof) => break,
            Err(_) => break,
            _ => {}
        }
        buf.clear();
    }

    (hosts, ports_set.into_iter().collect())
}

fn parse_live_hosts_from_xml(xml: &str) -> Result<Vec<String>> {
    use quick_xml::events::Event;
    use quick_xml::Reader;

    let mut reader = Reader::from_str(xml);
    reader.trim_text(true);
    let mut buf = Vec::new();
    let mut hosts = Vec::new();
    let mut in_host = false;
    let mut current_ip = None;
    let mut host_is_up = false;

    loop {
        match reader.read_event_into(&mut buf) {
            Ok(Event::Start(ref e)) | Ok(Event::Empty(ref e)) => match e.name().as_ref() {
                b"host" => {
                    in_host = true;
                    current_ip = None;
                    host_is_up = false;
                }
                b"address" if in_host => {
                    for attr in e.attributes().flatten() {
                        if attr.key.as_ref() == b"addr" {
                            current_ip = Some(String::from_utf8_lossy(&attr.value).to_string());
                        }
                    }
                }
                b"status" if in_host => {
                    for attr in e.attributes().flatten() {
                        if attr.key.as_ref() == b"state"
                            && String::from_utf8_lossy(&attr.value) == "up"
                        {
                            host_is_up = true;
                        }
                    }
                }
                _ => {}
            },
            Ok(Event::End(ref e)) => {
                if e.name().as_ref() == b"host" {
                    if host_is_up {
                        if let Some(ip) = current_ip.take() {
                            hosts.push(ip);
                        }
                    }
                    in_host = false;
                }
            }
            Ok(Event::Eof) => break,
            Err(e) => return Err(anyhow::anyhow!("XML parse error: {:?}", e)),
            _ => {}
        }
        buf.clear();
    }
    Ok(hosts)
}

// ── Public DTOs ─────────────────────────────────────────────────────────

#[derive(serde::Serialize, Debug, Clone)]
pub struct ActiveScan {
    pub scan_id: String,
    pub short_id: String, // first 8 chars — the "scan hash"
    pub targets: Vec<String>,
    pub phase: String,
    pub phase_label: String,
    pub phase_percent: f32,
    pub overall_percent: f32,
    pub hosts_discovered: usize,
    pub ports_discovered: u32,
    pub cancelled: bool,
    pub finished: bool,
    pub started_at: DateTime<Utc>,
    pub finished_at: Option<DateTime<Utc>>,
    pub log_count: usize,
}

impl ActiveScan {
    fn from_state(s: &ScanState, cancelled: bool) -> Self {
        Self {
            scan_id: s.id.clone(),
            short_id: s.id.chars().take(8).collect(),
            targets: s.config.targets.clone(),
            phase: format!("{:?}", s.phase),
            phase_label: s.phase.label(),
            phase_percent: s.phase_percent,
            overall_percent: s.overall_percent,
            hosts_discovered: s.hosts_discovered.len(),
            ports_discovered: s.ports_discovered,
            cancelled,
            finished: s.phase.is_terminal(),
            started_at: s.started_at,
            finished_at: s.finished_at,
            log_count: s.logs.len(),
        }
    }
}

#[derive(serde::Serialize, Debug, Clone)]
pub struct ScanLogSlice {
    pub scan_id: String,
    pub total: usize,
    pub offset: usize,
    pub lines: Vec<String>,
}
