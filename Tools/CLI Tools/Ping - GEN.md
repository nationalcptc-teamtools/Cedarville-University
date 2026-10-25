---
aliases:
  - "Ping"
generated: true
sources_checked: 2026-10-23
---

# Ping - GEN

Ping sends [[ICMP]] echo requests and measures replies. It supports reachability checks, packet-loss observations, and round-trip timing.

Examples use Linux iputils syntax:

```bash
ping -c 4 192.0.2.10
ping -4 example.com
ping -6 example.com
```

| Option | Purpose |
| --- | --- |
| `-c N` | Stop after the specified number of requests |
| `-4` / `-6` | Select the IP version |
| `-I INTERFACE` | Select an interface or source address |
| `-W N` | Wait for a response according to implementation semantics |

No echo reply does not establish that a host is offline; filtering and network conditions can affect the exchange. [[Tools/CLI Tools/Traceroute - GEN|Traceroute]] investigates responding hops, while [[NMAP]] can use other discovery probes.

**Source**
---
[iputils ping manual](https://man7.org/linux/man-pages/man8/ping.8.html)
