use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Host {
    pub id: i64,
    pub ip_address: String,
    pub hostname: Option<String>,
    pub mac_address: Option<String>,
    pub vendor: Option<String>,
    pub os: Option<String>,
    pub os_accuracy: Option<i32>,
    pub status: String,
    pub first_seen: DateTime<Utc>,
    pub last_seen: DateTime<Utc>,
    pub network_id: Option<i64>,
    pub investigation_status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Port {
    pub id: i64,
    pub host_id: i64,
    pub port_number: i32,
    pub protocol: String,
    pub state: String,
    pub service: Option<String>,
    pub version: Option<String>,
    pub product: Option<String>,
    pub extra_info: Option<String>,
    pub first_seen: DateTime<Utc>,
    pub last_seen: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct ScriptResult {
    pub id: i64,
    pub port_id: i64,
    pub script_name: String,
    pub output: String,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Network {
    pub id: i64,
    pub cidr: String,
    pub name: Option<String>,
    pub description: Option<String>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Scan {
    pub id: i64,
    pub scan_uuid: Option<String>,
    pub scan_type: String,
    pub targets: String,
    pub arguments: String,
    pub start_time: DateTime<Utc>,
    pub end_time: Option<DateTime<Utc>>,
    pub status: String,
    pub hosts_found: i32,
    pub ports_found: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScanConfig {
    pub targets: Vec<String>,
    pub excluded_targets: Vec<String>,
    pub scan_type: ScanType,
    pub evasion_enabled: bool,
    pub source_port: Option<u16>,
    pub dns_servers: Vec<String>,
    pub timing_template: TimingTemplate,
    pub udp_scan: bool,
    pub script_scan: bool,
    pub version_detection: bool,
    pub os_detection: bool,
    pub max_rate: Option<u32>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ScanType {
    Syn,
    Connect,
    Ack,
    Window,
    Maimon,
    Null,
    Fin,
    Xmas,
}

impl ScanType {
    pub fn to_nmap_flag(&self) -> &str {
        match self {
            ScanType::Syn => "-sS",
            ScanType::Connect => "-sT",
            ScanType::Ack => "-sA",
            ScanType::Window => "-sW",
            ScanType::Maimon => "-sM",
            ScanType::Null => "-sN",
            ScanType::Fin => "-sF",
            ScanType::Xmas => "-sX",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TimingTemplate {
    Paranoid,
    Sneaky,
    Polite,
    Normal,
    Aggressive,
    Insane,
}

impl TimingTemplate {
    pub fn to_nmap_flag(&self) -> &str {
        match self {
            TimingTemplate::Paranoid => "-T0",
            TimingTemplate::Sneaky => "-T1",
            TimingTemplate::Polite => "-T2",
            TimingTemplate::Normal => "-T3",
            TimingTemplate::Aggressive => "-T4",
            TimingTemplate::Insane => "-T5",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HostWithPorts {
    #[serde(flatten)]
    pub host: Host,
    pub ports: Vec<PortWithScripts>,
    pub assignments: Vec<ActiveAssignment>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HostFull {
    #[serde(flatten)]
    pub host: Host,
    pub ports: Vec<PortWithScripts>,
    pub assignments: Vec<ActiveAssignment>,
    pub notes: Vec<HostNote>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PortWithScripts {
    #[serde(flatten)]
    pub port: Port,
    pub scripts: Vec<ScriptResult>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NetworkTopology {
    pub networks: Vec<Network>,
    pub hosts: Vec<HostWithPorts>,
    pub connections: Vec<Connection>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Connection {
    pub source_id: i64,
    pub dest_id: i64,
    pub connection_type: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct TeamMember {
    pub id: i64,
    pub name: String,
    pub icon: String,
    pub created_at: DateTime<Utc>,
}

/// An assignment currently in effect, enriched with member & port info
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ActiveAssignment {
    pub assignment_id: i64,
    pub member_id: i64,
    pub member_name: String,
    pub member_icon: String,
    pub host_id: i64,
    pub port_id: Option<i64>,
    pub port_number: Option<i32>,
    pub port_protocol: Option<String>,
    pub assigned_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct HostNote {
    pub id: i64,
    pub host_id: i64,
    pub member_id: Option<i64>,
    pub member_name: Option<String>,
    pub member_icon: Option<String>,
    pub note: String,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct BlameEntry {
    pub id: i64,
    pub member_id: Option<i64>,
    pub member_name: Option<String>,
    pub member_icon: Option<String>,
    pub action: String,
    pub target_type: String,
    pub target_id: i64,
    pub target_label: Option<String>,
    pub details: Option<String>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct AssignRequest {
    pub member_id: i64,
    pub port_id: Option<i64>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct UnassignRequest {
    pub member_id: i64,
}

#[derive(Debug, Clone, Deserialize)]
pub struct StatusUpdateRequest {
    pub member_id: Option<i64>,
    pub status: String, // untouched | investigating | investigated | compromised
}

#[derive(Debug, Clone, Deserialize)]
pub struct NoteCreateRequest {
    pub member_id: Option<i64>,
    pub note: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct AddMembersRequest {
    /// Either a single name, or a newline/comma-separated block of names
    pub names: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct UpdateIconRequest {
    pub icon: String,
}
