use crate::models::*;
use anyhow::Result;
use chrono::Utc;
use sqlx::{Row, SqlitePool};

pub async fn migrate(pool: &SqlitePool) -> Result<()> {
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS networks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cidr TEXT NOT NULL UNIQUE,
            name TEXT,
            description TEXT,
            created_at TEXT NOT NULL
        )
        "#,
    )
    .execute(pool)
    .await?;

    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS hosts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ip_address TEXT NOT NULL UNIQUE,
            hostname TEXT,
            mac_address TEXT,
            vendor TEXT,
            os TEXT,
            os_accuracy INTEGER,
            status TEXT NOT NULL,
            first_seen TEXT NOT NULL,
            last_seen TEXT NOT NULL,
            network_id INTEGER,
            investigation_status TEXT NOT NULL DEFAULT 'untouched',
            FOREIGN KEY (network_id) REFERENCES networks(id)
        )
        "#,
    )
    .execute(pool)
    .await?;

    // Lightweight migration: add column if it doesn't exist on an older DB
    let _ = sqlx::query(
        "ALTER TABLE hosts ADD COLUMN investigation_status TEXT NOT NULL DEFAULT 'untouched'",
    )
    .execute(pool)
    .await;

    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS ports (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            host_id INTEGER NOT NULL,
            port_number INTEGER NOT NULL,
            protocol TEXT NOT NULL,
            state TEXT NOT NULL,
            service TEXT,
            version TEXT,
            product TEXT,
            extra_info TEXT,
            first_seen TEXT NOT NULL,
            last_seen TEXT NOT NULL,
            FOREIGN KEY (host_id) REFERENCES hosts(id),
            UNIQUE(host_id, port_number, protocol)
        )
        "#,
    )
    .execute(pool)
    .await?;

    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS script_results (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            port_id INTEGER NOT NULL,
            script_name TEXT NOT NULL,
            output TEXT NOT NULL,
            created_at TEXT NOT NULL,
            FOREIGN KEY (port_id) REFERENCES ports(id)
        )
        "#,
    )
    .execute(pool)
    .await?;

    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS scans (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            scan_uuid TEXT UNIQUE,
            scan_type TEXT NOT NULL,
            targets TEXT NOT NULL,
            arguments TEXT NOT NULL,
            start_time TEXT NOT NULL,
            end_time TEXT,
            status TEXT NOT NULL,
            hosts_found INTEGER DEFAULT 0,
            ports_found INTEGER DEFAULT 0
        )
        "#,
    )
    .execute(pool)
    .await?;
    // Lightweight migrations for pre-existing DBs
    let _ = sqlx::query("ALTER TABLE scans ADD COLUMN scan_uuid TEXT")
        .execute(pool)
        .await;
    let _ = sqlx::query("ALTER TABLE scans ADD COLUMN ports_found INTEGER DEFAULT 0")
        .execute(pool)
        .await;

    sqlx::query("CREATE INDEX IF NOT EXISTS idx_hosts_ip ON hosts(ip_address)")
        .execute(pool)
        .await?;

    sqlx::query("CREATE INDEX IF NOT EXISTS idx_ports_host ON ports(host_id)")
        .execute(pool)
        .await?;

    sqlx::query("CREATE INDEX IF NOT EXISTS idx_scripts_port ON script_results(port_id)")
        .execute(pool)
        .await?;

    // ── Team tables ─────────────────────────────────────────
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS team_members (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            icon TEXT NOT NULL,
            created_at TEXT NOT NULL
        )
        "#,
    )
    .execute(pool)
    .await?;

    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS assignments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            member_id INTEGER NOT NULL,
            host_id INTEGER NOT NULL,
            port_id INTEGER,
            assigned_at TEXT NOT NULL,
            released_at TEXT,
            FOREIGN KEY (member_id) REFERENCES team_members(id),
            FOREIGN KEY (host_id)   REFERENCES hosts(id),
            FOREIGN KEY (port_id)   REFERENCES ports(id)
        )
        "#,
    )
    .execute(pool)
    .await?;

    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS host_notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            host_id INTEGER NOT NULL,
            member_id INTEGER,
            note TEXT NOT NULL,
            created_at TEXT NOT NULL,
            FOREIGN KEY (host_id)   REFERENCES hosts(id),
            FOREIGN KEY (member_id) REFERENCES team_members(id)
        )
        "#,
    )
    .execute(pool)
    .await?;

    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS blame_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            member_id INTEGER,
            action TEXT NOT NULL,
            target_type TEXT NOT NULL,
            target_id INTEGER NOT NULL,
            details TEXT,
            created_at TEXT NOT NULL,
            FOREIGN KEY (member_id) REFERENCES team_members(id)
        )
        "#,
    )
    .execute(pool)
    .await?;

    sqlx::query(
        "CREATE INDEX IF NOT EXISTS idx_assign_active ON assignments(host_id, released_at)",
    )
    .execute(pool)
    .await?;
    sqlx::query(
        "CREATE INDEX IF NOT EXISTS idx_assign_member ON assignments(member_id, released_at)",
    )
    .execute(pool)
    .await?;
    sqlx::query("CREATE INDEX IF NOT EXISTS idx_notes_host ON host_notes(host_id)")
        .execute(pool)
        .await?;
    sqlx::query("CREATE INDEX IF NOT EXISTS idx_blame_time ON blame_log(created_at)")
        .execute(pool)
        .await?;

    Ok(())
}

pub async fn upsert_host(pool: &SqlitePool, host: &Host) -> Result<i64> {
    let result = sqlx::query(
        r#"
        INSERT INTO hosts (ip_address, hostname, mac_address, vendor, os, os_accuracy, status, first_seen, last_seen, network_id)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(ip_address) DO UPDATE SET
            hostname = COALESCE(excluded.hostname, hostname),
            mac_address = COALESCE(excluded.mac_address, mac_address),
            vendor = COALESCE(excluded.vendor, vendor),
            os = COALESCE(excluded.os, os),
            os_accuracy = COALESCE(excluded.os_accuracy, os_accuracy),
            status = excluded.status,
            last_seen = excluded.last_seen
        RETURNING id
        "#,
    )
    .bind(&host.ip_address)
    .bind(&host.hostname)
    .bind(&host.mac_address)
    .bind(&host.vendor)
    .bind(&host.os)
    .bind(host.os_accuracy)
    .bind(&host.status)
    .bind(host.first_seen.to_rfc3339())
    .bind(host.last_seen.to_rfc3339())
    .bind(host.network_id)
    .fetch_one(pool)
    .await?;

    Ok(result.get(0))
}

pub async fn upsert_port(pool: &SqlitePool, port: &Port) -> Result<i64> {
    let result = sqlx::query(
        r#"
        INSERT INTO ports (host_id, port_number, protocol, state, service, version, product, extra_info, first_seen, last_seen)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(host_id, port_number, protocol) DO UPDATE SET
            state = excluded.state,
            service = COALESCE(excluded.service, service),
            version = COALESCE(excluded.version, version),
            product = COALESCE(excluded.product, product),
            extra_info = COALESCE(excluded.extra_info, extra_info),
            last_seen = excluded.last_seen
        RETURNING id
        "#,
    )
    .bind(port.host_id)
    .bind(port.port_number)
    .bind(&port.protocol)
    .bind(&port.state)
    .bind(&port.service)
    .bind(&port.version)
    .bind(&port.product)
    .bind(&port.extra_info)
    .bind(port.first_seen.to_rfc3339())
    .bind(port.last_seen.to_rfc3339())
    .fetch_one(pool)
    .await?;

    Ok(result.get(0))
}

pub async fn insert_script_result(pool: &SqlitePool, script: &ScriptResult) -> Result<i64> {
    let result = sqlx::query(
        r#"
        INSERT INTO script_results (port_id, script_name, output, created_at)
        VALUES (?, ?, ?, ?)
        RETURNING id
        "#,
    )
    .bind(script.port_id)
    .bind(&script.script_name)
    .bind(&script.output)
    .bind(script.created_at.to_rfc3339())
    .fetch_one(pool)
    .await?;

    Ok(result.get(0))
}

pub async fn get_or_create_network(pool: &SqlitePool, cidr: &str) -> Result<i64> {
    let result = sqlx::query(
        r#"
        INSERT INTO networks (cidr, created_at)
        VALUES (?, ?)
        ON CONFLICT(cidr) DO UPDATE SET cidr = cidr
        RETURNING id
        "#,
    )
    .bind(cidr)
    .bind(Utc::now().to_rfc3339())
    .fetch_one(pool)
    .await?;

    Ok(result.get(0))
}

pub async fn get_all_hosts(pool: &SqlitePool) -> Result<Vec<Host>> {
    let rows = sqlx::query_as::<_, Host>(
        r#"
        SELECT id, ip_address, hostname, mac_address, vendor, os, os_accuracy,
               status, first_seen, last_seen, network_id, investigation_status
        FROM hosts
        ORDER BY ip_address
        "#,
    )
    .fetch_all(pool)
    .await?;

    Ok(rows)
}

pub async fn get_host_by_id(pool: &SqlitePool, host_id: i64) -> Result<Option<Host>> {
    let row = sqlx::query_as::<_, Host>(
        r#"
        SELECT id, ip_address, hostname, mac_address, vendor, os, os_accuracy,
               status, first_seen, last_seen, network_id, investigation_status
        FROM hosts
        WHERE id = ?
        "#,
    )
    .bind(host_id)
    .fetch_optional(pool)
    .await?;

    Ok(row)
}

/// Delete a host and everything owned by it. Blame-log entries referring to
/// the host are preserved (target_label will resolve to NULL on future joins).
pub async fn delete_host(pool: &SqlitePool, host_id: i64) -> Result<()> {
    // Order matters: `assignments` has FKs to BOTH hosts and ports, so it has
    // to go before ports. `script_results` is a child of ports and goes first.
    //
    //   script_results → ports → hosts
    //   assignments    → ports → hosts     (also references hosts directly)
    //   host_notes     → hosts
    //
    // sqlx-sqlite enforces FKs by default, so getting this order wrong raises
    // code 787.
    sqlx::query(
        "DELETE FROM script_results WHERE port_id IN (SELECT id FROM ports WHERE host_id = ?)",
    )
    .bind(host_id)
    .execute(pool)
    .await?;
    sqlx::query("DELETE FROM assignments WHERE host_id = ?")
        .bind(host_id)
        .execute(pool)
        .await?;
    sqlx::query("DELETE FROM host_notes WHERE host_id = ?")
        .bind(host_id)
        .execute(pool)
        .await?;
    sqlx::query("DELETE FROM ports WHERE host_id = ?")
        .bind(host_id)
        .execute(pool)
        .await?;
    sqlx::query("DELETE FROM hosts WHERE id = ?")
        .bind(host_id)
        .execute(pool)
        .await?;
    Ok(())
}

pub async fn get_ports_for_host(pool: &SqlitePool, host_id: i64) -> Result<Vec<Port>> {
    let rows = sqlx::query_as::<_, Port>(
        r#"
        SELECT id, host_id, port_number, protocol, state, service, version,
               product, extra_info, first_seen, last_seen
        FROM ports
        WHERE host_id = ?
        ORDER BY port_number
        "#,
    )
    .bind(host_id)
    .fetch_all(pool)
    .await?;

    Ok(rows)
}

pub async fn get_scripts_for_port(pool: &SqlitePool, port_id: i64) -> Result<Vec<ScriptResult>> {
    let rows = sqlx::query_as::<_, ScriptResult>(
        r#"
        SELECT id, port_id, script_name, output, created_at
        FROM script_results
        WHERE port_id = ?
        ORDER BY created_at DESC
        "#,
    )
    .bind(port_id)
    .fetch_all(pool)
    .await?;

    Ok(rows)
}

pub async fn get_all_networks(pool: &SqlitePool) -> Result<Vec<Network>> {
    let rows = sqlx::query_as::<_, Network>(
        r#"
        SELECT id, cidr, name, description, created_at
        FROM networks
        ORDER BY cidr
        "#,
    )
    .fetch_all(pool)
    .await?;

    Ok(rows)
}

pub async fn get_recent_scans(pool: &SqlitePool, limit: i64) -> Result<Vec<Scan>> {
    let rows = sqlx::query_as::<_, Scan>(
        r#"
        SELECT id, scan_uuid, scan_type, targets, arguments, start_time, end_time, status,
               hosts_found, ports_found
        FROM scans
        ORDER BY start_time DESC
        LIMIT ?
        "#,
    )
    .bind(limit)
    .fetch_all(pool)
    .await?;

    Ok(rows)
}

/// Record the start of a scan session. Called by ScanManager::start_scan.
pub async fn create_scan(
    pool: &SqlitePool,
    scan_uuid: &str,
    scan_type: &str,
    targets: &str,
    arguments: &str,
) -> Result<i64> {
    let row = sqlx::query(
        r#"
        INSERT INTO scans (scan_uuid, scan_type, targets, arguments, start_time, status, hosts_found, ports_found)
        VALUES (?, ?, ?, ?, ?, 'running', 0, 0)
        RETURNING id
        "#,
    )
    .bind(scan_uuid)
    .bind(scan_type)
    .bind(targets)
    .bind(arguments)
    .bind(Utc::now().to_rfc3339())
    .fetch_one(pool)
    .await?;
    Ok(row.get(0))
}

/// Mark a scan session as terminal (complete / failed / cancelled) and stamp
/// its final hosts/ports totals and end_time.
pub async fn finalize_scan(
    pool: &SqlitePool,
    scan_uuid: &str,
    status: &str,
    hosts_found: i32,
    ports_found: i32,
) -> Result<()> {
    sqlx::query(
        r#"
        UPDATE scans
        SET status = ?, end_time = ?, hosts_found = ?, ports_found = ?
        WHERE scan_uuid = ?
        "#,
    )
    .bind(status)
    .bind(Utc::now().to_rfc3339())
    .bind(hosts_found)
    .bind(ports_found)
    .bind(scan_uuid)
    .execute(pool)
    .await?;
    Ok(())
}

/// Update a running scan's progress counters (hosts/ports discovered so far).
pub async fn touch_scan_counters(
    pool: &SqlitePool,
    scan_uuid: &str,
    hosts_found: i32,
    ports_found: i32,
) -> Result<()> {
    sqlx::query("UPDATE scans SET hosts_found = ?, ports_found = ? WHERE scan_uuid = ?")
        .bind(hosts_found)
        .bind(ports_found)
        .bind(scan_uuid)
        .execute(pool)
        .await?;
    Ok(())
}

// ── Team members ────────────────────────────────────────

const DEFAULT_ICONS: &[&str] = &[
    "\u{1F98A}", // fox
    "\u{1F43A}", // wolf
    "\u{1F981}", // lion
    "\u{1F42F}", // tiger
    "\u{1F438}", // frog
    "\u{1F419}", // octopus
    "\u{1F989}", // owl
    "\u{1F422}", // turtle
    "\u{1F985}", // eagle
    "\u{1F427}", // penguin
    "\u{1F99D}", // raccoon
    "\u{1F428}", // koala
    "\u{1F43C}", // panda
    "\u{1F998}", // kangaroo
    "\u{1F994}", // hedgehog
    "\u{1F41D}", // bee
    "\u{1F98B}", // butterfly
    "\u{1F41E}", // ladybug
    "\u{1F980}", // crab
    "\u{1F433}", // whale
];

fn pick_icon(index: usize) -> String {
    DEFAULT_ICONS[index % DEFAULT_ICONS.len()].to_string()
}

pub async fn get_all_members(pool: &SqlitePool) -> Result<Vec<TeamMember>> {
    let rows = sqlx::query_as::<_, TeamMember>(
        "SELECT id, name, icon, created_at FROM team_members ORDER BY name",
    )
    .fetch_all(pool)
    .await?;
    Ok(rows)
}

pub async fn get_member_by_id(pool: &SqlitePool, id: i64) -> Result<Option<TeamMember>> {
    let row = sqlx::query_as::<_, TeamMember>(
        "SELECT id, name, icon, created_at FROM team_members WHERE id = ?",
    )
    .bind(id)
    .fetch_optional(pool)
    .await?;
    Ok(row)
}

pub async fn add_member(pool: &SqlitePool, name: &str) -> Result<TeamMember> {
    let name = name.trim();
    if name.is_empty() {
        return Err(anyhow::anyhow!("name empty"));
    }
    let count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM team_members")
        .fetch_one(pool)
        .await?;
    let icon = pick_icon(count as usize);
    let now = Utc::now();
    let row = sqlx::query(
        r#"
        INSERT INTO team_members (name, icon, created_at)
        VALUES (?, ?, ?)
        ON CONFLICT(name) DO UPDATE SET name = name
        RETURNING id, icon, created_at
        "#,
    )
    .bind(name)
    .bind(&icon)
    .bind(now.to_rfc3339())
    .fetch_one(pool)
    .await?;

    Ok(TeamMember {
        id: row.get(0),
        name: name.to_string(),
        icon: row.get(1),
        created_at: now,
    })
}

pub async fn update_member_icon(pool: &SqlitePool, id: i64, icon: &str) -> Result<()> {
    sqlx::query("UPDATE team_members SET icon = ? WHERE id = ?")
        .bind(icon)
        .bind(id)
        .execute(pool)
        .await?;
    Ok(())
}

pub async fn delete_member(pool: &SqlitePool, id: i64) -> Result<()> {
    let now = Utc::now().to_rfc3339();
    // Release active assignments
    sqlx::query(
        "UPDATE assignments SET released_at = ? WHERE member_id = ? AND released_at IS NULL",
    )
    .bind(&now)
    .bind(id)
    .execute(pool)
    .await?;
    // Preserve historical notes / blame log by nulling the author FK
    sqlx::query("UPDATE host_notes SET member_id = NULL WHERE member_id = ?")
        .bind(id)
        .execute(pool)
        .await?;
    sqlx::query("UPDATE blame_log  SET member_id = NULL WHERE member_id = ?")
        .bind(id)
        .execute(pool)
        .await?;
    // assignments.member_id is NOT NULL — drop historical rows for this member
    sqlx::query("DELETE FROM assignments WHERE member_id = ?")
        .bind(id)
        .execute(pool)
        .await?;
    sqlx::query("DELETE FROM team_members WHERE id = ?")
        .bind(id)
        .execute(pool)
        .await?;
    Ok(())
}

// ── Assignments ─────────────────────────────────────────

/// Create or re-focus an assignment. If the member already has an active
/// assignment on this host, update the port (if different) instead of adding
/// a duplicate row.
pub async fn assign_member(
    pool: &SqlitePool,
    member_id: i64,
    host_id: i64,
    port_id: Option<i64>,
) -> Result<i64> {
    // Check existing active assignment
    let existing: Option<(i64, Option<i64>)> = sqlx::query_as(
        "SELECT id, port_id FROM assignments WHERE member_id = ? AND host_id = ? AND released_at IS NULL",
    )
    .bind(member_id)
    .bind(host_id)
    .fetch_optional(pool)
    .await?;

    if let Some((aid, existing_port)) = existing {
        if existing_port != port_id {
            sqlx::query("UPDATE assignments SET port_id = ? WHERE id = ?")
                .bind(port_id)
                .bind(aid)
                .execute(pool)
                .await?;
        }
        return Ok(aid);
    }

    let row = sqlx::query(
        r#"
        INSERT INTO assignments (member_id, host_id, port_id, assigned_at)
        VALUES (?, ?, ?, ?)
        RETURNING id
        "#,
    )
    .bind(member_id)
    .bind(host_id)
    .bind(port_id)
    .bind(Utc::now().to_rfc3339())
    .fetch_one(pool)
    .await?;
    Ok(row.get(0))
}

pub async fn unassign_member(pool: &SqlitePool, member_id: i64, host_id: i64) -> Result<u64> {
    let res = sqlx::query(
        "UPDATE assignments SET released_at = ? WHERE member_id = ? AND host_id = ? AND released_at IS NULL",
    )
    .bind(Utc::now().to_rfc3339())
    .bind(member_id)
    .bind(host_id)
    .execute(pool)
    .await?;
    Ok(res.rows_affected())
}

pub async fn active_assignments_for_host(
    pool: &SqlitePool,
    host_id: i64,
) -> Result<Vec<ActiveAssignment>> {
    let rows = sqlx::query(
        r#"
        SELECT a.id, a.member_id, m.name, m.icon, a.host_id, a.port_id,
               p.port_number, p.protocol, a.assigned_at
        FROM assignments a
        JOIN team_members m ON a.member_id = m.id
        LEFT JOIN ports p ON a.port_id = p.id
        WHERE a.host_id = ? AND a.released_at IS NULL
        ORDER BY m.name
        "#,
    )
    .bind(host_id)
    .fetch_all(pool)
    .await?;

    Ok(rows
        .into_iter()
        .map(|r| ActiveAssignment {
            assignment_id: r.get(0),
            member_id: r.get(1),
            member_name: r.get(2),
            member_icon: r.get(3),
            host_id: r.get(4),
            port_id: r.get(5),
            port_number: r.get(6),
            port_protocol: r.get(7),
            assigned_at: chrono::DateTime::parse_from_rfc3339(&r.get::<String, _>(8))
                .map(|d| d.with_timezone(&Utc))
                .unwrap_or_else(|_| Utc::now()),
        })
        .collect())
}

pub async fn active_assignments_for_member(
    pool: &SqlitePool,
    member_id: i64,
) -> Result<Vec<ActiveAssignment>> {
    let rows = sqlx::query(
        r#"
        SELECT a.id, a.member_id, m.name, m.icon, a.host_id, a.port_id,
               p.port_number, p.protocol, a.assigned_at
        FROM assignments a
        JOIN team_members m ON a.member_id = m.id
        LEFT JOIN ports p ON a.port_id = p.id
        WHERE a.member_id = ? AND a.released_at IS NULL
        ORDER BY a.assigned_at DESC
        "#,
    )
    .bind(member_id)
    .fetch_all(pool)
    .await?;

    Ok(rows
        .into_iter()
        .map(|r| ActiveAssignment {
            assignment_id: r.get(0),
            member_id: r.get(1),
            member_name: r.get(2),
            member_icon: r.get(3),
            host_id: r.get(4),
            port_id: r.get(5),
            port_number: r.get(6),
            port_protocol: r.get(7),
            assigned_at: chrono::DateTime::parse_from_rfc3339(&r.get::<String, _>(8))
                .map(|d| d.with_timezone(&Utc))
                .unwrap_or_else(|_| Utc::now()),
        })
        .collect())
}

// ── Status ─────────────────────────────────────────────────

pub async fn set_investigation_status(pool: &SqlitePool, host_id: i64, status: &str) -> Result<()> {
    sqlx::query("UPDATE hosts SET investigation_status = ? WHERE id = ?")
        .bind(status)
        .bind(host_id)
        .execute(pool)
        .await?;
    Ok(())
}

// ── Notes ────────────────────────────────────────────────────

pub async fn add_host_note(
    pool: &SqlitePool,
    host_id: i64,
    member_id: Option<i64>,
    note: &str,
) -> Result<i64> {
    let row = sqlx::query(
        r#"
        INSERT INTO host_notes (host_id, member_id, note, created_at)
        VALUES (?, ?, ?, ?)
        RETURNING id
        "#,
    )
    .bind(host_id)
    .bind(member_id)
    .bind(note)
    .bind(Utc::now().to_rfc3339())
    .fetch_one(pool)
    .await?;
    Ok(row.get(0))
}

pub async fn get_host_notes(pool: &SqlitePool, host_id: i64) -> Result<Vec<HostNote>> {
    let rows = sqlx::query(
        r#"
        SELECT n.id, n.host_id, n.member_id, m.name, m.icon, n.note, n.created_at
        FROM host_notes n
        LEFT JOIN team_members m ON n.member_id = m.id
        WHERE n.host_id = ?
        ORDER BY n.created_at DESC
        "#,
    )
    .bind(host_id)
    .fetch_all(pool)
    .await?;

    Ok(rows
        .into_iter()
        .map(|r| HostNote {
            id: r.get(0),
            host_id: r.get(1),
            member_id: r.get(2),
            member_name: r.get(3),
            member_icon: r.get(4),
            note: r.get(5),
            created_at: chrono::DateTime::parse_from_rfc3339(&r.get::<String, _>(6))
                .map(|d| d.with_timezone(&Utc))
                .unwrap_or_else(|_| Utc::now()),
        })
        .collect())
}

pub async fn get_all_host_notes(pool: &SqlitePool) -> Result<Vec<HostNote>> {
    let rows = sqlx::query(
        r#"
        SELECT n.id, n.host_id, n.member_id, m.name, m.icon, n.note, n.created_at
        FROM host_notes n
        LEFT JOIN team_members m ON n.member_id = m.id
        ORDER BY n.created_at DESC
        "#,
    )
    .fetch_all(pool)
    .await?;

    Ok(rows
        .into_iter()
        .map(|r| HostNote {
            id: r.get(0),
            host_id: r.get(1),
            member_id: r.get(2),
            member_name: r.get(3),
            member_icon: r.get(4),
            note: r.get(5),
            created_at: chrono::DateTime::parse_from_rfc3339(&r.get::<String, _>(6))
                .map(|d| d.with_timezone(&Utc))
                .unwrap_or_else(|_| Utc::now()),
        })
        .collect())
}

// ── Blame log ──────────────────────────────────────────────

pub async fn log_blame(
    pool: &SqlitePool,
    member_id: Option<i64>,
    action: &str,
    target_type: &str,
    target_id: i64,
    details: Option<&str>,
) -> Result<()> {
    sqlx::query(
        r#"
        INSERT INTO blame_log (member_id, action, target_type, target_id, details, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
        "#,
    )
    .bind(member_id)
    .bind(action)
    .bind(target_type)
    .bind(target_id)
    .bind(details)
    .bind(Utc::now().to_rfc3339())
    .execute(pool)
    .await?;
    Ok(())
}

/// Blame log joined with member info and host ip (when target is a host).
pub async fn get_blame_log(
    pool: &SqlitePool,
    member_id: Option<i64>,
    limit: i64,
) -> Result<Vec<BlameEntry>> {
    let sql = r#"
        SELECT b.id, b.member_id, m.name, m.icon, b.action, b.target_type, b.target_id,
               h.ip_address, b.details, b.created_at
        FROM blame_log b
        LEFT JOIN team_members m ON b.member_id = m.id
        LEFT JOIN hosts h ON b.target_type = 'host' AND b.target_id = h.id
        WHERE (? IS NULL OR b.member_id = ?)
        ORDER BY b.created_at DESC
        LIMIT ?
    "#;
    let rows = sqlx::query(sql)
        .bind(member_id)
        .bind(member_id)
        .bind(limit)
        .fetch_all(pool)
        .await?;

    Ok(rows
        .into_iter()
        .map(|r| BlameEntry {
            id: r.get(0),
            member_id: r.get(1),
            member_name: r.get(2),
            member_icon: r.get(3),
            action: r.get(4),
            target_type: r.get(5),
            target_id: r.get(6),
            target_label: r.get(7),
            details: r.get(8),
            created_at: chrono::DateTime::parse_from_rfc3339(&r.get::<String, _>(9))
                .map(|d| d.with_timezone(&Utc))
                .unwrap_or_else(|_| Utc::now()),
        })
        .collect())
}
