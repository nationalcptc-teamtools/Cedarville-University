// ── API Base ──
const API_BASE = '/api';

// ── Global state ──
let hosts = [];
let networks = [];
let members = [];
let currentUserId = null;
let currentModalHostId = null;

// Active-scans monitor state
//   scanState[scan_id] = { logOffset, consoleEl, cardEl, cancelInFlight }
let scanState = {};
let activeScanPollTimer = null;
let onActiveTab = false;

const TAB_TITLES = {
    topology: 'Network Topology',
    hosts:    'Host List',
    team:     'Team',
    scanner:  'Scanner',
    active:   'Active Scans',
    import:   'Import Scans',
    export:   'Export',
};

// ── Boot ──
document.addEventListener('DOMContentLoaded', async () => {
    initSidebar();
    initTheme();
    initScanner();
    initImport();
    initModal();
    initTeam();
    initIconPicker();

    await refreshMembers();
    restoreCurrentUser();
    refreshTopology();
    refreshHosts();
    refreshBlame();

    // Kick a one-shot check for any pre-existing scans in the manager
    refreshActiveScans().then(() => {
        // If anything's active, polling will have been started by the renderer
        startActiveScanPolling();
    });
});

// Expose switchTab for inline handlers in dynamically-rendered content
window.switchTab = switchTab;

// ── Sidebar / Nav ──
function initSidebar() {
    const hamburger      = document.getElementById('hamburger');
    const sidebarToggle  = document.getElementById('sidebar-toggle');
    const sidebar        = document.getElementById('sidebar');
    const overlay        = document.getElementById('sidebar-overlay');

    // Topbar hamburger (mobile only) — toggles slide-in sidebar
    hamburger?.addEventListener('click', () => {
        const open = sidebar.classList.toggle('open');
        overlay.classList.toggle('open', open);
        hamburger.classList.toggle('open', open);
    });
    overlay?.addEventListener('click', closeSidebar);

    // Sidebar hamburger (desktop) — collapses / expands sidebar width
    sidebarToggle?.addEventListener('click', () => {
        const narrow = window.matchMedia('(max-width: 820px)').matches;
        if (narrow) {
            // On mobile the sidebar-toggle lives inside the sidebar; use it to close
            closeSidebar();
            return;
        }
        const collapsed = sidebar.classList.toggle('collapsed');
        document.body.classList.toggle('sidebar-collapsed', collapsed);
        localStorage.setItem('ph-sidebar-collapsed', collapsed ? '1' : '0');
    });

    // Restore collapsed state (desktop only)
    if (localStorage.getItem('ph-sidebar-collapsed') === '1'
        && !window.matchMedia('(max-width: 820px)').matches) {
        sidebar.classList.add('collapsed');
        document.body.classList.add('sidebar-collapsed');
    }

    document.querySelectorAll('.sidebar-nav .nav-item').forEach(btn => {
        btn.addEventListener('click', () => switchTab(btn.dataset.tab));
    });

    document.getElementById('refresh-topology')?.addEventListener('click', refreshTopology);
    document.getElementById('refresh-hosts')?.addEventListener('click', refreshHosts);
    document.getElementById('host-search')?.addEventListener('input', filterHosts);
    document.getElementById('refresh-active')?.addEventListener('click', refreshActiveScans);
}

function closeSidebar() {
    document.getElementById('sidebar').classList.remove('open');
    document.getElementById('sidebar-overlay').classList.remove('open');
    document.getElementById('hamburger').classList.remove('open');
}

function switchTab(name) {
    document.querySelectorAll('.sidebar-nav .nav-item').forEach(b => {
        b.classList.toggle('active', b.dataset.tab === name);
    });
    document.querySelectorAll('.tab-content').forEach(el => {
        el.classList.toggle('active', el.id === name + '-tab');
    });
    document.getElementById('page-title').textContent = TAB_TITLES[name] || name;
    closeSidebar();

    onActiveTab = (name === 'active');
    if (name === 'team') { refreshMembers(); refreshBlame(); }
    if (name === 'topology') refreshTopology();
    if (name === 'hosts') refreshHosts();
    if (name === 'active') refreshActiveScans();
}

// ── Theme ──
function initTheme() {
    const saved = localStorage.getItem('ph-theme');
    if (saved) document.documentElement.setAttribute('data-theme', saved);
    syncThemeIcon();
    document.getElementById('theme-toggle').addEventListener('click', () => {
        const next = document.documentElement.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
        document.documentElement.setAttribute('data-theme', next);
        localStorage.setItem('ph-theme', next);
        syncThemeIcon();
    });
}
function syncThemeIcon() {
    const dark = document.documentElement.getAttribute('data-theme') === 'dark';
    document.getElementById('theme-icon-dark').style.display  = dark ? 'block' : 'none';
    document.getElementById('theme-icon-light').style.display = dark ? 'none'  : 'block';
}

// ── Current user ──
function restoreCurrentUser() {
    const saved = localStorage.getItem('ph-current-user');
    if (saved && members.find(m => m.id == saved)) {
        currentUserId = parseInt(saved, 10);
    }
    const sel = document.getElementById('current-user-select');
    sel.value = currentUserId || '';
    sel.addEventListener('change', e => {
        currentUserId = e.target.value ? parseInt(e.target.value, 10) : null;
        if (currentUserId) localStorage.setItem('ph-current-user', currentUserId);
        else localStorage.removeItem('ph-current-user');
    });
}

function populateCurrentUserSelect() {
    const sel = document.getElementById('current-user-select');
    const existing = sel.value;
    sel.innerHTML = '<option value="">Not set</option>';
    members.forEach(m => {
        const o = document.createElement('option');
        o.value = m.id;
        // <option> can't render images; strip to a text label for the dropdown
        o.textContent = iconLabelForSelect(m.icon) + ' ' + m.name;
        sel.appendChild(o);
    });
    sel.value = existing;
}

function populateBlameFilter() {
    const sel = document.getElementById('blame-filter');
    if (!sel) return;
    const existing = sel.value;
    sel.innerHTML = '<option value="">All members</option>';
    members.forEach(m => {
        const o = document.createElement('option');
        o.value = m.id;
        o.textContent = iconLabelForSelect(m.icon) + ' ' + m.name;
        sel.appendChild(o);
    });
    sel.value = existing;
    sel.onchange = () => refreshBlame(sel.value || null);
}

// ── OS Classification ──
const WIN_PORTS = new Set([135, 139, 445, 3389, 5985, 5986, 1433, 593, 49152, 49153, 49154]);
const NIX_PORTS = new Set([22, 111, 2049, 6000, 6001]);

function classifyOS(host) {
    const os = (host.os || '').toLowerCase();
    if (/windows|win32|microsoft/.test(os)) return 'windows';
    if (/linux|ubuntu|debian|centos|fedora|redhat|rhel|suse|kali|arch/.test(os)) return 'linux';
    if (/bsd|freebsd|openbsd|netbsd|darwin|mac\s?os|os\s?x/.test(os)) return 'linux';
    if (/solaris|sunos|aix|hp-ux|unix/.test(os)) return 'linux';
    if (os && !/unknown/.test(os)) return 'other';

    const openPorts = new Set(host.ports.filter(p => p.state === 'open').map(p => p.port_number));
    const openSvcs = host.ports.filter(p => p.state === 'open')
        .map(p => ((p.service || '') + ' ' + (p.product || '') + ' ' + (p.extra_info || '')).toLowerCase());

    if (openPorts.has(445) || openPorts.has(135) || openPorts.has(3389)) return 'windows';
    if (openSvcs.some(s => /microsoft|\biis\b|ms-sql|netbios|\bsmb\b|windows/.test(s))) return 'windows';

    let winScore = 0, nixScore = 0;
    openPorts.forEach(p => { if (WIN_PORTS.has(p)) winScore++; if (NIX_PORTS.has(p)) nixScore++; });
    if (winScore > nixScore && winScore >= 2) return 'windows';

    if (openSvcs.some(s => /openssh|apache|nginx|postfix|bind|exim|sendmail|proftpd|vsftpd|dovecot|sshd/.test(s))) return 'linux';
    if (openPorts.has(22)) return 'linux';

    return 'other';
}

const OS_META = {
    linux:   { label: 'Linux / Unix',    icon: '🐧', css: 'os-linux'   },
    windows: { label: 'Windows',         icon: '🪟', css: 'os-windows' },
    other:   { label: 'Other / Unknown', icon: '❓', css: 'os-other'   },
};

const STATUS_META = {
    untouched:     { label: 'Untouched',     icon: '○' },
    investigating: { label: 'Investigating', icon: '🔍' },
    investigated:  { label: 'Investigated',  icon: '✓' },
    compromised:   { label: 'Compromised',   icon: '💥' },
};

// ── Topology ──
async function refreshTopology() {
    try {
        const topo = await fetchJSON('/topology');
        networks = topo.networks;
        hosts = topo.hosts;
        renderTopologyStats(topo);
        renderTopology(topo);
    } catch (e) { console.error('Topology error:', e); }
}

function renderTopology(topo) {
    const el = document.getElementById('topology-graph');
    el.innerHTML = '';
    if (!topo.hosts.length) {
        el.innerHTML = '<p style="text-align:center;padding:40px;color:var(--text-muted)">No hosts yet. Import a scan or launch one.</p>';
        return;
    }
    topo.hosts.forEach(h => { h._osType = classifyOS(h); });

    const groups = {};
    topo.hosts.forEach(h => {
        const nid = h.network_id || 'unknown';
        (groups[nid] = groups[nid] || []).push(h);
    });

    Object.entries(groups).forEach(([nid, list]) => {
        const net = topo.networks.find(n => n.id == nid);
        const osCounts = { linux: 0, windows: 0, other: 0 };
        list.forEach(h => osCounts[h._osType]++);

        const section = document.createElement('div');
        section.className = 'network-group';

        const header = document.createElement('div');
        header.className = 'network-header';
        header.innerHTML =
            '<h3>' + esc(net ? net.cidr : 'Unknown Network') + '</h3>' +
            '<div class="os-chips">' +
                (osCounts.linux   ? '<span class="os-chip os-linux">'   + OS_META.linux.icon   + ' ' + osCounts.linux   + '</span>' : '') +
                (osCounts.windows ? '<span class="os-chip os-windows">' + OS_META.windows.icon + ' ' + osCounts.windows + '</span>' : '') +
                (osCounts.other   ? '<span class="os-chip os-other">'   + OS_META.other.icon   + ' ' + osCounts.other   + '</span>' : '') +
            '</div>';
        section.appendChild(header);

        ['linux', 'windows', 'other'].forEach(osType => {
            const osHosts = list.filter(h => h._osType === osType);
            if (!osHosts.length) return;
            const meta = OS_META[osType];

            const sub = document.createElement('div');
            sub.className = 'os-subgroup-label ' + meta.css;
            sub.innerHTML = '<span class="os-subgroup-icon">' + meta.icon + '</span> ' + meta.label;
            section.appendChild(sub);

            const grid = document.createElement('div');
            grid.className = 'hosts-grid';
            osHosts.forEach(host => {
                const open = host.ports.filter(p => p.state === 'open').length;
                const invest = host.investigation_status || 'untouched';
                const memberIcons = (host.assignments || []).map(a =>
                    '<span class="member-icon-only" title="' + esc(a.member_name) +
                    (a.port_number ? ' on ' + a.port_number + '/' + (a.port_protocol || 'tcp') : '') +
                    '">' + renderIcon(a.member_icon) + '</span>'
                ).join('');

                const card = document.createElement('div');
                card.className = 'topo-host ' + meta.css;
                card.onclick = () => openHostFromTopology(host.id);
                card.innerHTML =
                    '<div class="topo-host-top">' +
                        '<div class="topo-host-ip">' + esc(host.ip_address) + '</div>' +
                        '<div class="topo-member-stack">' +
                            '<span class="os-badge ' + meta.css + '">' + meta.icon + '</span>' +
                            memberIcons +
                        '</div>' +
                    '</div>' +
                    '<div class="topo-host-name">' + esc(host.hostname || '—') + '</div>' +
                    (host.os ? '<div class="topo-host-os">' + esc(host.os) + '</div>' : '') +
                    '<div class="topo-host-footer">' +
                        '<span class="port-count">' + open + ' open</span> ' +
                        '<span class="invest-badge invest-' + invest + '">' + (STATUS_META[invest] ? STATUS_META[invest].icon : '○') + ' ' + invest + '</span>' +
                    '</div>';
                grid.appendChild(card);
            });
            section.appendChild(grid);
        });
        el.appendChild(section);
    });
}

/// Clicking a topology host switches to the hosts tab AND opens the detail modal.
function openHostFromTopology(hostId) {
    switchTab('hosts');
    setTimeout(() => showHostDetail(hostId), 100);
}

function renderTopologyStats(topo) {
    const panel = document.getElementById('topology-stats');
    const total = topo.hosts.length;
    const up    = topo.hosts.filter(h => h.status === 'up').length;
    const open  = topo.hosts.reduce((s, h) => s + h.ports.filter(p => p.state === 'open').length, 0);
    topo.hosts.forEach(h => { if (!h._osType) h._osType = classifyOS(h); });
    const linuxCount   = topo.hosts.filter(h => h._osType === 'linux').length;
    const windowsCount = topo.hosts.filter(h => h._osType === 'windows').length;
    const otherCount   = topo.hosts.filter(h => h._osType === 'other').length;

    panel.innerHTML =
        '<div class="stat-grid">' +
            stat(total, 'Hosts') + stat(up, 'Up') +
            stat(open, 'Open Ports') + stat(topo.networks.length, 'Networks') +
        '</div>' +
        '<div class="stat-section-label">Operating Systems</div>' +
        '<div class="stat-grid stat-grid-os">' +
            statOS(linuxCount, OS_META.linux) +
            statOS(windowsCount, OS_META.windows) +
            statOS(otherCount, OS_META.other) +
        '</div>';
}

function stat(val, label) {
    return '<div class="stat-item"><div class="stat-value">' + val + '</div><div class="stat-label">' + label + '</div></div>';
}
function statOS(val, meta) {
    return '<div class="stat-item stat-os ' + meta.css + '"><div class="stat-value">' + meta.icon + ' ' + val + '</div><div class="stat-label">' + meta.label + '</div></div>';
}

// ── Host list ──
async function refreshHosts() {
    try {
        const list = await fetchJSON('/hosts');
        // Enrich each host with its active assignments (one topology call is cheap)
        const topo = await fetchJSON('/topology');
        const map = new Map(topo.hosts.map(h => [h.id, h]));
        list.forEach(h => {
            const t = map.get(h.id);
            h.assignments = t ? t.assignments : [];
            h.open_count  = t ? t.ports.filter(p => p.state === 'open').length : 0;
        });
        renderHostsList(list);
    } catch (e) { console.error('Hosts error:', e); }
}

function renderHostsList(list) {
    const el = document.getElementById('hosts-list');
    el.innerHTML = '';
    if (!list.length) {
        el.innerHTML = '<p style="text-align:center;padding:40px;color:var(--text-muted)">No hosts found.</p>';
        return;
    }
    list.forEach(host => {
        const invest = host.investigation_status || 'untouched';
        const card = document.createElement('div');
        card.className = 'host-card';
        card.onclick = () => showHostDetail(host.id);

        const teamRow = (host.assignments && host.assignments.length)
            ? '<div class="host-team-row">' +
                '<span class="label">Assigned</span>' +
                host.assignments.map(a => renderMemberChip(a)).join('') +
              '</div>'
            : '';

        card.innerHTML =
            '<button class="host-delete-btn" title="Delete host" aria-label="Delete host" ' +
                'onclick="event.stopPropagation(); deleteHost(' + host.id + ', \'' + esc(host.ip_address).replace(/'/g, "\\'") + '\')">' +
                '<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' +
                    '<polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/><path d="M10 11v6"/><path d="M14 11v6"/><path d="M9 6V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2"/>' +
                '</svg>' +
            '</button>' +
            '<div class="host-header">' +
                '<div class="host-ip">' + esc(host.ip_address) + '</div>' +
                '<div style="display:flex;gap:6px;flex-wrap:wrap;align-items:center">' +
                    '<span class="host-status ' + host.status + '">' + host.status.toUpperCase() + '</span>' +
                    '<span class="invest-badge invest-' + invest + '">' + (STATUS_META[invest] ? STATUS_META[invest].icon : '○') + ' ' + invest + '</span>' +
                '</div>' +
            '</div>' +
            '<div class="host-info">' +
                infoItem('Hostname', host.hostname) +
                infoItem('OS', host.os) +
                infoItem('MAC', host.mac_address) +
                infoItem('Open Ports', host.open_count || 0) +
            '</div>' +
            teamRow;
        el.appendChild(card);
    });
}

function renderMemberChip(a) {
    const port = a.port_number ? ' <span class="focus-port">· ' + a.port_number + '/' + (a.port_protocol || 'tcp') + '</span>' : '';
    return '<span class="member-chip"><span class="icon">' + renderIcon(a.member_icon) + '</span>' + esc(a.member_name) + port + '</span>';
}

function filterHosts(e) {
    const q = e.target.value.toLowerCase();
    document.querySelectorAll('.host-card').forEach(c => {
        c.style.display = c.textContent.toLowerCase().includes(q) ? '' : 'none';
    });
}

// ── Host detail modal ──
async function showHostDetail(id) {
    try {
        currentModalHostId = id;
        const host = await fetchJSON('/hosts/' + id);
        renderHostModal(host);
        document.getElementById('host-modal').style.display = 'block';
    } catch (e) { console.error('Detail error:', e); }
}

function renderHostModal(host) {
    const invest  = host.investigation_status || 'untouched';
    const openCnt = host.ports.filter(p => p.state === 'open').length;
    const el = document.getElementById('host-detail');

    el.innerHTML =
        '<h2>' + esc(host.ip_address) + '</h2>' +
        renderTeamPanel(host) +
        '<div class="detail-section">' +
            '<h3>Host Information</h3>' +
            '<div class="host-info">' +
                infoItem('Hostname', host.hostname) +
                infoItem('Status', host.status) +
                infoItem('OS', (host.os || 'Unknown') + (host.os_accuracy ? ' (' + host.os_accuracy + '%)' : '')) +
                infoItem('MAC', host.mac_address) +
                infoItem('Vendor', host.vendor) +
                infoItem('Investigation', '<span class="invest-badge invest-' + invest + '">' + (STATUS_META[invest] ? STATUS_META[invest].icon : '○') + ' ' + invest + '</span>') +
            '</div>' +
        '</div>' +
        renderNotesPanel(host) +
        '<div class="detail-section">' +
            '<div class="ports-header">' +
                '<h3 style="margin:0">Ports (' + openCnt + ' open)</h3>' +
                '<label class="port-sort-label">Sort' +
                    '<select id="port-sort-mode">' +
                        '<option value="availability"' + (portSortMode==='availability' ? ' selected' : '') + '>By availability</option>' +
                        '<option value="number"'       + (portSortMode==='number'       ? ' selected' : '') + '>By port number</option>' +
                        '<option value="service"'      + (portSortMode==='service'      ? ' selected' : '') + '>By service</option>' +
                    '</select>' +
                '</label>' +
            '</div>' +
            '<div id="ports-list-container">' + renderPorts(host.ports, host.id) + '</div>' +
        '</div>' +
        '<div class="danger-zone">' +
            '<div>' +
                '<strong>Delete this host</strong>' +
                '<p>Removes the host, every port, every script result, all team assignments, and all notes. The blame log entry is preserved for audit history. This cannot be undone.</p>' +
            '</div>' +
            '<button class="btn-danger" data-action="delete-host">Delete host</button>' +
        '</div>';

    // Wire up buttons
    bindModalActions(host);
}

function renderTeamPanel(host) {
    const invest = host.investigation_status || 'untouched';
    const chips  = (host.assignments || []).map(a => renderMemberChip(a)).join('') || '<span style="color:var(--text-muted);font-size:.9rem">No one assigned yet.</span>';

    const youAssigned = currentUserId && host.assignments.some(a => a.member_id === currentUserId);

    // Build "focus port" dropdown with open ports
    const openPorts = host.ports.filter(p => p.state === 'open');
    let portOpts = '<option value="">(no specific port)</option>';
    openPorts.forEach(p => {
        const sel = (youAssigned && host.assignments.find(a => a.member_id === currentUserId && a.port_id === p.id)) ? ' selected' : '';
        portOpts += '<option value="' + p.id + '"' + sel + '>' + p.port_number + '/' + p.protocol + ' (' + (p.service || '?') + ')</option>';
    });

    let actions = '';
    if (!currentUserId) {
        actions = '<div style="font-size:.85rem;color:var(--text-muted);margin-top:8px">Select who you are in the sidebar to assign yourself.</div>';
    } else {
        actions =
            '<div class="assign-controls">' +
                '<label style="font-size:.85rem;color:var(--text-muted)">Focus port:</label>' +
                '<select id="assign-port-select">' + portOpts + '</select>' +
                (youAssigned
                    ? '<button class="assign-btn leave" data-action="unassign">Unassign me</button>'
                    : '<button class="assign-btn join" data-action="assign">Assign me</button>') +
                (youAssigned ? '<button class="assign-btn join" data-action="assign" title="Update focus port">Update focus</button>' : '') +
            '</div>';
    }

    const statusBtns =
        '<div class="status-buttons">' +
            Object.entries(STATUS_META).map(([key, meta]) =>
                '<button class="status-btn ' + (invest === key ? 'active-' + key : '') + '" data-status="' + key + '">' +
                meta.icon + ' ' + meta.label +
                '</button>'
            ).join('') +
        '</div>';

    return '<div class="modal-team-section">' +
        '<div style="display:flex;flex-wrap:wrap;align-items:center;gap:8px;margin-bottom:8px">' +
            '<strong style="font-size:.85rem;text-transform:uppercase;letter-spacing:.05em;color:var(--text-muted)">Team on this host</strong>' +
        '</div>' +
        '<div>' + chips + '</div>' +
        actions +
        '<div style="margin-top:14px"><strong style="font-size:.85rem;text-transform:uppercase;letter-spacing:.05em;color:var(--text-muted)">Investigation Status</strong></div>' +
        statusBtns +
    '</div>';
}

function renderNotesPanel(host) {
    const notesHtml = (host.notes && host.notes.length)
        ? host.notes.map(n => {
            const author = n.member_name
                ? renderIcon(n.member_icon) + ' ' + esc(n.member_name)
                : '<em style="color:var(--text-muted)">anonymous</em>';
            return '<div class="note">' +
                '<div class="note-header">' +
                    '<span class="note-author">' + author + '</span>' +
                    '<span>' + fmtDate(n.created_at) + '</span>' +
                '</div>' +
                '<div class="note-body">' + esc(n.note) + '</div>' +
            '</div>';
          }).join('')
        : '<p style="color:var(--text-muted);font-size:.9rem">No notes yet.</p>';

    return '<div class="detail-section">' +
        '<h3>Notes</h3>' +
        '<div class="notes-list">' + notesHtml + '</div>' +
        '<div class="note-form">' +
            '<textarea id="note-input" placeholder="Add a note..."></textarea>' +
            '<button class="btn btn-accent" data-action="add-note">Add</button>' +
        '</div>' +
    '</div>';
}

function bindModalActions(host) {
    const el = document.getElementById('host-detail');

    el.querySelectorAll('[data-action="assign"]').forEach(b => {
        b.onclick = async () => {
            if (!currentUserId) return;
            const portSel = document.getElementById('assign-port-select');
            const portId  = portSel && portSel.value ? parseInt(portSel.value, 10) : null;
            await apiPost('/hosts/' + host.id + '/assign', { member_id: currentUserId, port_id: portId });
            await refreshAfterChange(host.id);
        };
    });
    el.querySelectorAll('[data-action="unassign"]').forEach(b => {
        b.onclick = async () => {
            if (!currentUserId) return;
            await apiPost('/hosts/' + host.id + '/unassign', { member_id: currentUserId });
            await refreshAfterChange(host.id);
        };
    });
    el.querySelectorAll('[data-status]').forEach(b => {
        b.onclick = async () => {
            const status = b.dataset.status;
            await apiPut('/hosts/' + host.id + '/status', {
                member_id: currentUserId || null,
                status,
            });
            await refreshAfterChange(host.id);
        };
    });
    el.querySelectorAll('[data-action="add-note"]').forEach(b => {
        b.onclick = async () => {
            const input = document.getElementById('note-input');
            const text  = input.value.trim();
            if (!text) return;
            await apiPost('/hosts/' + host.id + '/notes', {
                member_id: currentUserId || null,
                note: text,
            });
            input.value = '';
            await refreshAfterChange(host.id);
        };
    });
    el.querySelectorAll('[data-action="delete-host"]').forEach(b => {
        b.onclick = () => deleteHost(host.id, host.ip_address);
    });
    const sortSel = document.getElementById('port-sort-mode');
    if (sortSel) {
        sortSel.addEventListener('change', e => {
            portSortMode = e.target.value;
            localStorage.setItem('ph-port-sort', portSortMode);
            const container = document.getElementById('ports-list-container');
            if (container) container.innerHTML = renderPorts(host.ports, host.id);
        });
    }
}

async function refreshAfterChange(hostId) {
    const h = await fetchJSON('/hosts/' + hostId);
    renderHostModal(h);
    refreshTopology();
    refreshHosts();
    refreshBlame();
}

/// Delete a host (and all its ports / notes / assignments). Called from the
/// per-row trash button and from the modal's danger zone. Keeps the blame
/// log entry around so audit history survives.
async function deleteHost(hostId, label) {
    if (!confirm('Delete host ' + label + '?\n\n' +
                 'All its ports, script results, team assignments, and notes ' +
                 'will be removed. This cannot be undone.')) return;
    try {
        const url = '/hosts/' + hostId + (currentUserId ? '?member_id=' + currentUserId : '');
        const r = await fetch(API_BASE + url, { method: 'DELETE' });
        const data = await r.json().catch(() => ({}));
        if (!r.ok) throw new Error(data.error || ('HTTP ' + r.status));

        // Close the modal if it was open on this host
        if (currentModalHostId === hostId) {
            document.getElementById('host-modal').style.display = 'none';
            currentModalHostId = null;
        }

        // Propagate everywhere
        refreshTopology();
        refreshHosts();
        refreshBlame();
    } catch (e) {
        alert('Delete failed: ' + e.message);
    }
}
window.deleteHost = deleteHost;

/// Ordering of port states by "availability" — open-ish states first,
/// unknown last. Lower rank = earlier in list.
const PORT_STATE_RANK = {
    'open':             0,
    'open|filtered':    1,
    'unfiltered':       2,
    'filtered':         3,
    'closed|filtered':  4,
    'closed':           5,
};
let portSortMode = (localStorage.getItem('ph-port-sort') || 'availability');

function sortPorts(ports) {
    const copy = ports.slice();
    switch (portSortMode) {
        case 'number':
            copy.sort((a, b) => a.port_number - b.port_number);
            break;
        case 'service':
            copy.sort((a, b) => {
                const sa = (a.service || '~').toLowerCase();
                const sb = (b.service || '~').toLowerCase();
                if (sa === sb) return a.port_number - b.port_number;
                return sa.localeCompare(sb);
            });
            break;
        case 'availability':
        default:
            copy.sort((a, b) => {
                const ra = PORT_STATE_RANK[a.state] ?? 99;
                const rb = PORT_STATE_RANK[b.state] ?? 99;
                if (ra !== rb) return ra - rb;
                return a.port_number - b.port_number;
            });
    }
    return copy;
}

function renderPorts(ports, hostId) {
    if (!ports.length) return '<p class="muted">No ports discovered.</p>';
    return sortPorts(ports).map(p => {
        const scripts = p.scripts || [];
        return '<div class="port-detail" data-state="' + esc(p.state) + '">' +
            '<div class="port-header">' +
                '<div class="port-number">' + p.port_number + '/' + p.protocol + '</div>' +
                '<div class="host-status ' + p.state + '">' + p.state + '</div>' +
            '</div>' +
            '<div class="host-info">' +
                infoItem('Service', p.service) +
                infoItem('Product', p.product) +
                infoItem('Version', p.version) +
                (p.extra_info ? infoItem('Extra', p.extra_info) : '') +
            '</div>' +
            (scripts.length ? '<div style="margin-top:10px"><strong style="font-size:.8rem">NSE Scripts</strong>' +
                scripts.map(s =>
                    '<div style="margin-top:6px">' +
                        '<div style="color:var(--primary);font-weight:600;font-size:.82rem">' + esc(s.script_name) + '</div>' +
                        '<div class="script-output">' + esc(s.output) + '</div>' +
                    '</div>'
                ).join('') +
            '</div>' : '') +
        '</div>';
    }).join('');
}

function initModal() {
    const modal = document.getElementById('host-modal');
    document.getElementById('modal-close-btn').onclick = () => modal.style.display = 'none';
    window.addEventListener('click', e => { if (e.target === modal) modal.style.display = 'none'; });
    window.addEventListener('keydown', e => { if (e.key === 'Escape') modal.style.display = 'none'; });
}

// ── Team tab ──
function initTeam() {
    document.getElementById('add-members-btn')?.addEventListener('click', addMembers);
    document.getElementById('members-file')?.addEventListener('change', async e => {
        const f = e.target.files[0];
        if (f) document.getElementById('members-input').value = await f.text();
    });
}

async function refreshMembers() {
    try {
        members = await fetchJSON('/members');
        populateCurrentUserSelect();
        populateBlameFilter();
        renderTeamRoster();
    } catch (e) { console.error('Members error:', e); }
}

async function renderTeamRoster() {
    const el = document.getElementById('team-list');
    if (!el) return;
    if (!members.length) {
        el.innerHTML = '<p class="muted">No team members yet.</p>';
        return;
    }

    // Load each member's active assignments in parallel
    const rows = await Promise.all(members.map(async m => {
        try {
            const assigns = await fetchJSON('/members/' + m.id + '/assignments');
            return { member: m, assignments: assigns };
        } catch (_) {
            return { member: m, assignments: [] };
        }
    }));

    el.innerHTML = rows.map(({ member, assignments }) => {
        const you = currentUserId === member.id ? ' (you)' : '';
        const assignHtml = assignments.length
            ? assignments.map(a => {
                const host = hosts.find(h => h.id === a.host_id);
                const label = host ? host.ip_address + (host.hostname ? ' (' + host.hostname + ')' : '') : 'host#' + a.host_id;
                const port  = a.port_number ? ' · :' + a.port_number : '';
                return '<a onclick="openHostFromTeam(' + a.host_id + ')">' + esc(label) + port + '</a>';
            }).join(' ')
            : '<span>No active assignments</span>';

        return '<div class="team-member-row" data-member-id="' + member.id + '">' +
            '<div class="avatar" title="Click to change icon" onclick="openIconPicker(' + member.id + ')">' + renderIcon(member.icon) + '</div>' +
            '<div style="flex:1;min-width:0">' +
                '<div class="name">' + esc(member.name) + esc(you) + '</div>' +
                '<div class="assignments">' + assignHtml + '</div>' +
            '</div>' +
            '<button class="remove-btn" onclick="removeMember(' + member.id + ')">Remove</button>' +
        '</div>';
    }).join('');
}

async function addMembers() {
    const input = document.getElementById('members-input');
    const names = input.value.trim();
    if (!names) return;
    try {
        const r = await apiPost('/members', { names });
        input.value = '';
        document.getElementById('members-file').value = '';
        await refreshMembers();
        await refreshTopology();
        await refreshHosts();
    } catch (e) { console.error('Add members:', e); }
}

async function removeMember(id) {
    if (!confirm('Remove this team member? They will be unassigned from all hosts.')) return;
    try {
        await fetch(API_BASE + '/members/' + id, { method: 'DELETE' });
        if (currentUserId === id) {
            currentUserId = null;
            localStorage.removeItem('ph-current-user');
        }
        await refreshMembers();
        await refreshTopology();
        await refreshHosts();
        await refreshBlame();
    } catch (e) { console.error('Remove member:', e); }
}
window.removeMember = removeMember;

// ── Icon rendering & picker ──

/// Render a member icon. Emoji / short text is returned verbatim; data: URIs
/// are wrapped in an <img>. Any other HTTP(S) URL is also wrapped in an <img>.
function renderIcon(icon) {
    if (!icon) return '';
    const trimmed = String(icon).trim();
    if (trimmed.startsWith('data:image/') || /^https?:\/\//.test(trimmed)) {
        return '<img src="' + esc(trimmed) + '" alt="" />';
    }
    return esc(trimmed);
}

/// For use inside <option> elements where images aren't allowed.
function iconLabelForSelect(icon) {
    if (!icon) return '';
    const t = String(icon).trim();
    if (t.startsWith('data:image/') || /^https?:\/\//.test(t)) return '🖼';
    return t;
}

const AVAILABLE_ICONS = [
    '🦊','🐺','🦁','🐯','🐸','🐙','🦉','🐢','🦅','🐧',
    '🦝','🐨','🐼','🦘','🦔','🐝','🦋','🐞','🦀','🐳',
    '🐱','🐶','🐰','🐹','🐭','🦄','🐲','🦖','🦕','🦑',
    '🐠','🐬','🦈','🦦','🦡','🦚','🦜','🐓','🐔','💓',
    '🌵','🌴','🌸','🍀','🍄','⭐','✨','💫','🔥','⚡',
    '🚀','🛸','🛰','⚙️','🔧','🔨','🧲','💎','👑','🎯',
    '🎲','🎸','🎷','🥷','🧙','🦸','🧛','🤖','👻','💀',
    '🌲','🌳','🌷','🌹','🌻','🌼','🌿','🍂','🍊','🍋',
];

let iconPickerTargetId = null;

function openIconPicker(memberId) {
    const member = members.find(m => m.id === memberId);
    if (!member) return;
    iconPickerTargetId = memberId;

    document.getElementById('icon-picker-name').textContent = '— ' + member.name;
    const grid = document.getElementById('icon-grid');
    grid.innerHTML = AVAILABLE_ICONS.map(ic => {
        const sel = (ic === member.icon) ? ' selected' : '';
        return '<button class="' + sel.trim() + '" data-icon="' + ic + '">' + ic + '</button>';
    }).join('');
    grid.querySelectorAll('button').forEach(btn => {
        btn.addEventListener('click', () => saveMemberIcon(btn.dataset.icon));
    });

    document.getElementById('icon-custom-input').value = '';
    document.getElementById('icon-upload-status').textContent = '';
    document.getElementById('icon-upload-input').value = '';
    document.getElementById('icon-picker-modal').style.display = 'block';
}
window.openIconPicker = openIconPicker;

async function saveMemberIcon(icon) {
    if (!iconPickerTargetId || !icon) return;
    try {
        await apiPut('/members/' + iconPickerTargetId + '/icon', { icon });
        document.getElementById('icon-picker-modal').style.display = 'none';
        iconPickerTargetId = null;
        // Propagate everywhere
        await refreshMembers();
        await refreshTopology();
        await refreshHosts();
        await refreshBlame();
    } catch (e) {
        alert('Failed to update icon: ' + e.message);
    }
}

function initIconPicker() {
    document.getElementById('icon-picker-close')?.addEventListener('click',
        () => document.getElementById('icon-picker-modal').style.display = 'none');

    document.getElementById('icon-save-custom')?.addEventListener('click', () => {
        const val = document.getElementById('icon-custom-input').value.trim();
        if (!val) return;
        if (val.length > 8) return alert('Max 8 characters for emoji / short text.');
        saveMemberIcon(val);
    });

    document.getElementById('icon-upload-input')?.addEventListener('change', async e => {
        const file = e.target.files[0];
        if (!file) return;
        const statusEl = document.getElementById('icon-upload-status');

        if (file.size > 50 * 1024) {
            statusEl.textContent = 'File too large (max 50 KB).';
            return;
        }
        if (!/image\/(png|svg\+xml|jpeg|webp)/.test(file.type)) {
            statusEl.textContent = 'Unsupported format — use PNG, SVG, JPEG or WebP.';
            return;
        }
        statusEl.textContent = 'Encoding…';
        try {
            const dataUri = await fileToDataUri(file);
            // For raster images, downsize to 128x128 to keep DB tidy
            const resized = /image\/svg/.test(file.type) ? dataUri : await resizeDataUri(dataUri, 128);
            await saveMemberIcon(resized);
        } catch (err) {
            statusEl.textContent = 'Upload failed: ' + err.message;
        }
    });

    // Close on backdrop click
    document.getElementById('icon-picker-modal')?.addEventListener('click', e => {
        if (e.target.id === 'icon-picker-modal') {
            document.getElementById('icon-picker-modal').style.display = 'none';
        }
    });
}

function fileToDataUri(file) {
    return new Promise((resolve, reject) => {
        const r = new FileReader();
        r.onload  = () => resolve(r.result);
        r.onerror = () => reject(new Error('read failed'));
        r.readAsDataURL(file);
    });
}

function resizeDataUri(src, size) {
    return new Promise((resolve, reject) => {
        const img = new Image();
        img.onload = () => {
            const canvas = document.createElement('canvas');
            canvas.width = size; canvas.height = size;
            const ctx = canvas.getContext('2d');
            // Centered cover-crop
            const scale = Math.max(size / img.width, size / img.height);
            const w = img.width * scale;
            const h = img.height * scale;
            ctx.drawImage(img, (size - w) / 2, (size - h) / 2, w, h);
            resolve(canvas.toDataURL('image/png'));
        };
        img.onerror = () => reject(new Error('image load failed'));
        img.src = src;
    });
}

/// Called from a team-roster link to jump to a host's detail modal
function openHostFromTeam(hostId) {
    switchTab('hosts');
    setTimeout(() => showHostDetail(hostId), 100);
}
window.openHostFromTeam = openHostFromTeam;

// ── Blame log ──
async function refreshBlame(memberId) {
    try {
        const url = memberId ? '/members/' + memberId + '/blame' : '/blame';
        const entries = await fetchJSON(url);
        renderBlameLog(entries);
    } catch (e) { console.error('Blame error:', e); }
}

function renderBlameLog(entries) {
    const el = document.getElementById('blame-list');
    if (!el) return;
    if (!entries.length) {
        el.innerHTML = '<p class="muted">No activity yet.</p>';
        return;
    }
    el.innerHTML = entries.map(b => {
        const who   = b.member_name ? (renderIcon(b.member_icon) + ' ' + esc(b.member_name)) : 'system';
        const label = b.target_label || (b.target_type + '#' + b.target_id);
        const det   = b.details ? ' <span style="color:var(--text-muted)">(' + esc(b.details) + ')</span>' : '';
        return '<div class="blame-entry">' +
            '<div class="icon">' + (b.member_icon ? renderIcon(b.member_icon) : '⚙️') + '</div>' +
            '<div>' +
                '<span class="action-tag action-' + b.action + '">' + b.action.replace('_', ' ') + '</span>' +
                '<strong>' + who + '</strong> → ' + esc(label) + det +
            '</div>' +
            '<div class="time">' + fmtDate(b.created_at) + '</div>' +
        '</div>';
    }).join('');
}

// ── Scanner ──
function initScanner() {
    document.getElementById('evasion-enabled').addEventListener('change', e => {
        document.getElementById('evasion-options').style.display = e.target.checked ? 'block' : 'none';
    });
    document.getElementById('start-scan')?.addEventListener('click', startScan);
}

async function startScan() {
    const targets    = val('scan-targets').split('\n').filter(Boolean);
    const exclusions = val('scan-exclusions').split('\n').filter(Boolean);
    if (!targets.length) return alert('Enter at least one target.');

    const evasion = document.getElementById('evasion-enabled').checked;
    const config = {
        targets,
        excluded_targets: exclusions,
        scan_type: val('scan-type'),
        timing_template: val('timing'),
        version_detection: chk('version-detection'),
        os_detection: chk('os-detection'),
        script_scan: chk('script-scan'),
        udp_scan: chk('udp-scan'),
        evasion_enabled: evasion,
        source_port: evasion ? (parseInt(val('source-port')) || null) : null,
        dns_servers: evasion ? val('dns-servers').split(',').map(s => s.trim()).filter(Boolean) : [],
        max_rate: parseInt(val('max-rate')) || null,
    };

    const notice = document.getElementById('scanner-launch-notice');
    try {
        const r = await apiPost('/scans', config);
        notice.className = 'result-panel success';
        notice.innerHTML = 'Scan <strong>' + r.scan_id.slice(0, 8) + '</strong> launched. ' +
            '<a href="#" style="color:inherit;text-decoration:underline" onclick="switchTab(\'active\');return false">View in Active Scans →</a>';
        notice.style.display = 'block';
        startActiveScanPolling();
        // auto-redirect after a brief moment
        setTimeout(() => switchTab('active'), 800);
    } catch (e) {
        notice.className = 'result-panel error';
        notice.textContent = 'Failed to start scan: ' + e.message;
        notice.style.display = 'block';
    }
}

// ── Active Scans tab ──

async function refreshActiveScans() {
    try {
        const list = await fetchJSON('/scans/active');
        renderActiveScans(list);
        updateActiveBadge(list);
    } catch (e) { console.error('Active scans:', e); }
}

/** Poll every 2s whenever there's at least one active scan (regardless of tab). */
function startActiveScanPolling() {
    if (activeScanPollTimer) return;
    activeScanPollTimer = setInterval(async () => {
        try {
            const list = await fetchJSON('/scans/active');
            updateActiveBadge(list);
            if (onActiveTab) {
                renderActiveScans(list);
            }
            // Stop polling if no scans at all
            if (list.length === 0) {
                stopActiveScanPolling();
            }
        } catch (_) {}
    }, 2000);
}

function stopActiveScanPolling() {
    if (activeScanPollTimer) {
        clearInterval(activeScanPollTimer);
        activeScanPollTimer = null;
    }
}

function updateActiveBadge(list) {
    const badge = document.getElementById('active-scans-badge');
    if (!badge) return;
    const running = list.filter(s => !s.finished).length;
    if (running > 0) {
        badge.textContent = running;
        badge.style.display = 'inline-block';
    } else {
        badge.style.display = 'none';
    }
}

function renderActiveScans(list) {
    const el = document.getElementById('active-scans-list');
    if (!el) return;
    if (!list.length) {
        el.innerHTML = '<p style="text-align:center;padding:40px;color:var(--text-muted)">No scans yet. Launch one from the Scanner tab.</p>';
        scanState = {};
        return;
    }

    const seen = new Set();
    list.forEach(scan => {
        seen.add(scan.scan_id);
        let st = scanState[scan.scan_id];
        if (!st) {
            st = { logOffset: 0, cancelInFlight: false };
            scanState[scan.scan_id] = st;
            const card = buildScanCard(scan);
            el.appendChild(card);
            st.cardEl = card;
            st.consoleEl = card.querySelector('.scan-console');
        }
        updateScanCard(st, scan);
        pollScanLogs(scan.scan_id);
    });

    // Remove cards for scans no longer in the list (pruned by server)
    Object.keys(scanState).forEach(id => {
        if (!seen.has(id)) {
            if (scanState[id].cardEl && scanState[id].cardEl.parentNode) {
                scanState[id].cardEl.remove();
            }
            delete scanState[id];
        }
    });
}

function buildScanCard(scan) {
    const card = document.createElement('div');
    card.className = 'active-scan-card';
    card.dataset.scanId = scan.scan_id;
    card.innerHTML =
        '<div class="scan-card-header">' +
            '<div style="display:flex;align-items:center;gap:10px;flex-wrap:wrap">' +
                '<span class="scan-hash">' + esc(scan.short_id) + '</span>' +
                '<span class="scan-phase-pill running" data-role="phase">' + esc(scan.phase_label) + '</span>' +
            '</div>' +
            '<button class="scan-cancel-btn" data-role="cancel">Cancel</button>' +
        '</div>' +
        '<div class="scan-targets" data-role="targets"></div>' +
        '<div class="scan-summary-grid" data-role="summary"></div>' +
        '<div class="scan-progress-wrap">' +
            '<div class="scan-progress-label">' +
                '<span>Overall</span>' +
                '<span data-role="overall-pct">0%</span>' +
            '</div>' +
            '<div class="scan-progress-track"><div class="scan-progress-fill" data-role="overall-fill" style="width:0%"></div></div>' +
        '</div>' +
        '<div class="scan-progress-wrap">' +
            '<div class="scan-progress-label">' +
                '<span>Current phase</span>' +
                '<span data-role="phase-pct">0%</span>' +
            '</div>' +
            '<div class="scan-progress-track"><div class="scan-progress-fill" data-role="phase-fill" style="width:0%"></div></div>' +
        '</div>' +
        '<div class="scan-console" data-role="console"></div>';

    card.querySelector('[data-role="cancel"]').addEventListener('click', () => cancelScan(scan.scan_id));
    return card;
}

function updateScanCard(st, scan) {
    const el = st.cardEl;
    if (!el) return;

    const phasePill = el.querySelector('[data-role="phase"]');
    phasePill.textContent = scan.phase_label;
    phasePill.className = 'scan-phase-pill ' + phaseClass(scan);

    el.className = 'active-scan-card' + (scan.finished ? ' terminal' : '') + ' ' + phaseClass(scan);

    el.querySelector('[data-role="targets"]').textContent = (scan.targets || []).join(', ') || '—';

    const elapsed = scan.finished && scan.finished_at
        ? Math.round((new Date(scan.finished_at) - new Date(scan.started_at)) / 1000)
        : Math.round((Date.now() - new Date(scan.started_at)) / 1000);

    el.querySelector('[data-role="summary"]').innerHTML =
        summaryItem('Scan hash', scan.short_id) +
        summaryItem('Hosts',  scan.hosts_discovered) +
        summaryItem('Ports',  scan.ports_discovered) +
        summaryItem('Elapsed', fmtDuration(elapsed));

    el.querySelector('[data-role="overall-pct"]').textContent = scan.overall_percent.toFixed(1) + '%';
    const of = el.querySelector('[data-role="overall-fill"]');
    of.style.width = scan.overall_percent + '%';
    of.className = 'scan-progress-fill ' + phaseClass(scan);

    el.querySelector('[data-role="phase-pct"]').textContent = scan.phase_percent.toFixed(1) + '%';
    const pf = el.querySelector('[data-role="phase-fill"]');
    pf.style.width = scan.phase_percent + '%';
    pf.className = 'scan-progress-fill ' + phaseClass(scan);

    const cancelBtn = el.querySelector('[data-role="cancel"]');
    if (scan.finished) {
        cancelBtn.disabled = true;
        cancelBtn.textContent = scan.cancelled ? 'Cancelled' : (scan.phase.startsWith('Failed') ? 'Failed' : 'Complete');
    } else if (st.cancelInFlight) {
        cancelBtn.disabled = true;
        cancelBtn.textContent = 'Cancelling…';
    }
}

function phaseClass(scan) {
    if (scan.cancelled) return 'cancelled';
    if (scan.phase === 'Complete') return 'complete';
    if (scan.phase.startsWith('Failed')) return 'failed';
    return 'running';
}

function summaryItem(label, value) {
    return '<div class="scan-summary-item"><div class="label">' + label + '</div><div class="value">' + esc(value) + '</div></div>';
}

function fmtDuration(secs) {
    if (secs < 60) return secs + 's';
    const m = Math.floor(secs / 60);
    const s = secs % 60;
    if (m < 60) return m + 'm ' + s + 's';
    return Math.floor(m / 60) + 'h ' + (m % 60) + 'm';
}

async function pollScanLogs(scanId) {
    const st = scanState[scanId];
    if (!st) return;
    try {
        const slice = await fetchJSON('/scans/' + scanId + '/logs?since=' + st.logOffset);
        if (slice.lines.length === 0) return;
        st.logOffset = slice.total;
        appendConsoleLines(st.consoleEl, slice.lines);
    } catch (_) {}
}

function appendConsoleLines(consoleEl, lines) {
    if (!consoleEl) return;
    const auto = document.getElementById('auto-scroll-logs')?.checked;
    const wasAtBottom = consoleEl.scrollHeight - consoleEl.scrollTop - consoleEl.clientHeight < 50;

    const frag = document.createDocumentFragment();
    lines.forEach(line => {
        const div = document.createElement('div');
        div.className = classifyLine(line);
        div.textContent = line;
        frag.appendChild(div);
    });
    consoleEl.appendChild(frag);

    // Cap on-screen lines (keep most recent 500)
    while (consoleEl.children.length > 500) consoleEl.removeChild(consoleEl.firstChild);

    if (auto || wasAtBottom) consoleEl.scrollTop = consoleEl.scrollHeight;
}

function classifyLine(line) {
    if (line.startsWith('$ '))        return 'line-prompt';
    if (line.startsWith('[→]'))       return 'line-arrow';
    if (line.startsWith('[✓]') || line.startsWith('[↓]')) return 'line-ok';
    if (line.startsWith('[!]'))       return 'line-err';
    if (/\berror\b|FAIL|failed/i.test(line)) return 'line-err';
    if (/Timing: About/i.test(line))  return 'line-warn';
    return '';
}

async function cancelScan(scanId) {
    const st = scanState[scanId];
    if (!st || st.cancelInFlight) return;
    if (!confirm('Cancel scan ' + scanId.slice(0,8) + '? Running nmap/masscan processes will be killed.')) return;
    st.cancelInFlight = true;
    try {
        await apiPost('/scans/' + scanId + '/cancel', {});
    } catch (e) {
        console.error('Cancel failed:', e);
        st.cancelInFlight = false;
    }
    refreshActiveScans();
}

// ── Import ──
function initImport() {
    document.getElementById('xml-file')?.addEventListener('change', async e => {
        const f = e.target.files[0];
        if (f) document.getElementById('xml-paste').value = await f.text();
    });
    document.getElementById('import-xml')?.addEventListener('click', importNmap);
}

async function importNmap() {
    const xml = val('xml-paste');
    if (!xml) return;
    const panel = document.getElementById('import-result');
    try {
        const r = await apiPost('/import', { xml });
        panel.className = 'result-panel success';
        panel.textContent = 'Imported ' + r.hosts_imported + ' hosts, ' + r.ports_imported + ' ports, ' + r.scripts_imported + ' scripts.';
        document.getElementById('xml-paste').value = '';
        document.getElementById('xml-file').value  = '';
        setTimeout(() => { refreshTopology(); refreshHosts(); }, 500);
    } catch (e) {
        panel.className = 'result-panel error';
        panel.textContent = 'Import failed: ' + e.message;
    }
    setTimeout(() => { panel.className = 'result-panel'; }, 6000);
}

// ── HTTP helpers ──
async function fetchJSON(path) {
    const r = await fetch(API_BASE + path);
    if (!r.ok) throw new Error('HTTP ' + r.status);
    return r.json();
}
async function apiPost(path, body) {
    const r = await fetch(API_BASE + path, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
    });
    const data = await r.json().catch(() => ({}));
    if (!r.ok) throw new Error(data.error || ('HTTP ' + r.status));
    return data;
}
async function apiPut(path, body) {
    const r = await fetch(API_BASE + path, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
    });
    const data = await r.json().catch(() => ({}));
    if (!r.ok) throw new Error(data.error || ('HTTP ' + r.status));
    return data;
}

// ── Utility ──
function val(id) { return document.getElementById(id).value.trim(); }
function chk(id) { return document.getElementById(id).checked; }
function esc(s) { if (s === null || s === undefined || s === '') return ''; const d = document.createElement('div'); d.textContent = String(s); return d.innerHTML; }
function fmtDate(s) { if (!s) return '—'; return new Date(s).toLocaleString(); }
function infoItem(label, value) {
    const v = (value === null || value === undefined || value === '') ? '—' : value;
    const html = (typeof v === 'string' && v.startsWith('<')) ? v : esc(v);
    return '<div class="info-item"><div class="info-label">' + label + '</div><div class="info-value">' + html + '</div></div>';
}
