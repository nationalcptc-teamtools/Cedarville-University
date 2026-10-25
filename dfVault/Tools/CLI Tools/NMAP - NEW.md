---
review_status: new
---

# Nmap

Nmap performs host discovery, port scanning, service identification, operating system fingerprinting, and scripted enumeration. It is used during [[Enumeration and Scanning]] to build an evidence-based map of a network.

## Scanning workflow

1. Define target addresses and exclusions.
2. Discover live hosts.
3. Resolve names when useful.
4. Scan TCP and UDP ports.
5. Identify service versions.
6. Estimate operating systems and network paths.
7. Run relevant NSE scripts.
8. Save results and validate important findings.

```bash
nmap [options] TARGET
```

Raw packet operations generally require elevated privileges. A TCP connect scan can run without raw packet privileges.

## Target selection and name resolution

| Input or option | Meaning |
| --- | --- |
| `192.0.2.10 example.com` | A list of targets |
| `192.0.2.10-15` | An inclusive address range |
| `192.0.2.0/24` | A subnet in [[CIDR]] notation |
| `-iL targets.txt` | Read targets from a file |
| `-sL` | List targets without port scanning; DNS lookups may still occur |
| `-n` | Disable reverse DNS resolution |
| `-R` | Resolve names for all target addresses |
| `--dns-servers DNS_SERVER` | Select DNS servers |

```bash
nmap -n -sL -iL targets.txt
```

## Host discovery

Nmap normally discovers hosts before scanning their ports. `-sn` performs discovery without a port scan; `-Pn` skips discovery and treats targets as online.

On a local Ethernet network, ARP discovery can identify hosts even when ICMP echo is blocked. Across routers, discovery relies on IP-layer probes. Default probes depend on privileges and network location.

| Option | Probe | Useful response |
| --- | --- | --- |
| `-PR` | [[ARP]] query on the local subnet | ARP reply |
| `-PE` | [[ICMP]] echo request, type 8 | Echo reply, type 0 |
| `-PP` | ICMP timestamp request, type 13 | Timestamp reply, type 14 |
| `-PM` | ICMP address mask request, type 17 | Address mask reply, type 18 |
| `-PS22,80,443` | TCP SYN probes to selected ports | SYN/ACK or RST |
| `-PA80` | TCP ACK probes | RST |
| `-PU40125` | UDP probe | UDP response or an ICMP error indicating a live host |

```bash
sudo nmap -PR -sn 192.0.2.0/24
sudo nmap -PE -PP -sn 192.0.2.0/24
sudo nmap -PS22,80,443 -sn 192.0.2.0/24
```

An unanswered probe does not establish that a host is offline. Firewalls, routing, packet loss, and unsupported ICMP types affect discovery. [[Arp-scan]] provides dedicated local ARP enumeration; Masscan provides high-rate scanning with different operational tradeoffs.

## Port selection and states

| Option | Selection |
| --- | --- |
| `-p22,80,443` | Specific ports |
| `-p1-1023` | An inclusive range |
| `-p-` | Ports 1 through 65535 |
| `-F` | The 100 most common ports |
| `--top-ports 10` | The ten most common ports |
| `-r` | Scan in numerical order |

The default selection is the 1,000 most common ports for the selected protocol. Port numbers range from 0 through 65535; TCP and UDP have separate port spaces. Common assignments are listed in [[Ports]].

| State | Interpretation |
| --- | --- |
| `open` | A service is accepting traffic on the port |
| `closed` | The target is reachable but no service is listening |
| `filtered` | Filtering or missing responses prevent a determination |
| `unfiltered` | The port is reachable, but the scan cannot distinguish open from closed |
| `open\|filtered` | Neither an open port nor filtering can be ruled out |
| `closed\|filtered` | Neither a closed port nor filtering can be ruled out |

## Basic port scans

| Scan | Option | Behavior |
| --- | --- | --- |
| TCP connect | `-sT` | Uses the operating system to complete a [[TCP]] handshake |
| TCP SYN | `-sS` | Sends SYN; SYN/ACK indicates open, RST indicates closed; does not complete the handshake |
| UDP | `-sU` | Uses [[UDP]] probes and interprets replies and ICMP errors |

```bash
nmap -sT -p22,80,443 TARGET
sudo nmap -sS -p- TARGET
sudo nmap -sU --top-ports 100 TARGET
```

For UDP, an ICMP type 3/code 3 response indicates a closed port. A valid UDP service response can confirm an open port. Silence commonly produces `open|filtered`, not proof that a service is listening. UDP scans can be slow because of retransmissions and ICMP rate limiting.

A SYN scan can still be observed and logged by network monitoring; an incomplete handshake does not make a scan invisible.

## Advanced TCP scans

| Scan | Option | Flags and interpretation |
| --- | --- | --- |
| Null | `-sN` | No flags; RST usually indicates closed; silence often means open or filtered |
| FIN | `-sF` | FIN; RST usually indicates closed |
| Xmas | `-sX` | FIN, PSH, URG; RST usually indicates closed |
| Maimon | `-sM` | FIN and ACK; depends on unusual target behavior |
| ACK | `-sA` | Maps filtering; RST indicates unfiltered, not an open service |
| Window | `-sW` | Examines TCP window values in RST responses on susceptible implementations |
| Custom | `--scanflags FLAGS` | Supplies a custom flag combination |

```bash
sudo nmap -sA -p80,443 TARGET
sudo nmap --scanflags RSTSYNFIN TARGET
```

These interpretations depend on the target TCP implementation and filtering behavior. Null, FIN, and Xmas scans may pass some stateless rules that focus on SYN, while stateful filtering may reject unexpected packets. None is a general firewall bypass.

## Timing and traffic controls

| Option | Effect |
| --- | --- |
| `-T0` | Paranoid timing; very slow, including long probe delays |
| `-T1` | Sneaky |
| `-T2` | Polite |
| `-T3` | Normal; default timing template |
| `-T4` | Aggressive |
| `-T5` | Insane; may reduce accuracy on unsuitable networks |
| `--min-rate N` / `--max-rate N` | Bounds the packet rate |
| `--min-parallelism N` / `--max-parallelism N` | Bounds outstanding probes |

```bash
sudo nmap -sS --max-rate 50 TARGET
```

Choose timing for network capacity, packet loss, and assessment constraints. A faster scan can miss results; a slow scan is still detectable.

## Service, operating system, and route identification

| Option | Purpose |
| --- | --- |
| `-sV` | Probe services for protocol and version details |
| `--version-intensity 0-9` | Set service probe intensity |
| `--version-light` | Light version detection, intensity 2 |
| `--version-all` | Full version detection, intensity 9 |
| `-O` | Estimate the [[Architecture/Operating System - GEN\|Operating System]] using network fingerprints |
| `--traceroute` | Estimate the route to the target |
| `-A` | Enable version detection, OS detection, default scripts, and traceroute |

```bash
nmap -sV --version-light -p22,80,443 TARGET
sudo nmap -O --traceroute TARGET
```

Service probes can establish application connections after SYN discovery. OS detection is an estimate affected by virtualization, filtering, and kernel customization. Nmap's route probing differs from a conventional traceroute that simply increments TTL from one.

## Source addresses, fragmentation, and idle scans

| Option | Purpose or limitation |
| --- | --- |
| `-S SPOOFED_IP` | Spoof the source IP; replies go to that address |
| `-e INTERFACE` | Select an interface |
| `--spoof-mac MAC` | Change the source [[Protocols and Notation/MAC Address - GEN\|MAC Address]] used for supported local operations |
| `-D DECOY1,ME,DECOY2` | Include decoy source addresses |
| `-f` / `-ff` | Request small IP fragments |
| `--mtu N` | Set a fragmentation size that is a multiple of eight |
| `--data-length N` | Append payload bytes |
| `-sI ZOMBIE_IP` | Use an idle host's IP ID behavior to infer port state |

IP spoofing requires a way to observe or infer responses. MAC spoofing is relevant on the local link. Fragmentation can affect some filtering or IDS implementations but is not a reliable evasion mechanism.

An idle scan samples a quiet host's IP ID, sends a SYN to the target with that host's source address, and samples the ID again. An open target port can send SYN/ACK to the idle host, causing it to emit a RST and increment the counter. The inference depends on a predictable counter and sufficiently little unrelated traffic.

## Nmap Scripting Engine

NSE runs Lua [[Scripts]] for enumeration and assessment. `-sC` is equivalent to selecting the default script category; `--script` selects names or expressions.

```bash
nmap -sV -sC -p80,443 TARGET
nmap --script http-methods -p80 TARGET
nmap --script http-webdav-scan -p80 TARGET
nmap --script http-ntlm-info --script-args http-ntlm-info.root=/webdav/ -p80 TARGET
```

| Category | Focus |
| --- | --- |
| `auth` | Authentication |
| `broadcast` | Broadcast-based discovery |
| `brute` | Password auditing |
| `default` | The default script set |
| `discovery` | Accessible service and system information |
| `dos` | Denial-of-service checks |
| `exploit` | Exploitation |
| `external` | Third-party service queries |
| `fuzzer` | Fuzzing |
| `intrusive` | Potentially disruptive behavior |
| `malware` | Malware and backdoor checks |
| `safe` | Lower-impact checks; still review individual behavior |
| `version` | Service version identification |
| `vuln` | Vulnerability checks |

For IIS, `http-methods` lists advertised methods, `http-webdav-scan` inspects WebDAV capabilities, and `http-ntlm-info` can expose host, domain, and build information. `http-iis-webdav-vuln` targets a specific historical WebDAV authentication bypass; it is not a general test for every IIS version.

## Output and troubleshooting

| Option | Output |
| --- | --- |
| `--reason` | Explain state classifications |
| `-v` / `-vv` | Increase verbosity |
| `-d` / `-dd` | Debug details |
| `-oN scan.txt` | Normal text |
| `-oG scan.gnmap` | Grepable output |
| `-oX scan.xml` | XML |
| `-oA scan` | Normal, grepable, and XML files with one basename |
| `-oS scan.txt` | Stylized text output |

```bash
nmap -sV --reason -oA service-scan TARGET
```

Keep the command, target, timestamp, and important response details together. Confirm significant service or vulnerability claims with protocol-specific evidence.

## Related concepts

- [[Architecture/IDS - GEN|IDS]]
- [[Architecture/Firewall - GEN|Firewall]]
