---
aliases:
  - "Traceroute"
generated: true
sources_checked: 2026-10-23
---

# Traceroute - GEN

Traceroute probes the route toward a destination using controlled IP time-to-live values. Intermediate routers can return [[ICMP]] time-exceeded responses when probes expire.

Linux examples:

```bash
traceroute example.com
traceroute -I example.com
traceroute -T -p 443 example.com
```

- `-I`: Use ICMP probes.
- `-T`: Use TCP SYN probes.
- `-p`: Select a port according to the chosen method.
- `-m`: Set a maximum hop count.

An asterisk means the expected response did not arrive within the timeout. Filtering or rate limiting can hide a hop without preventing forwarding.

Compare with [[Tools/CLI Tools/Ping - GEN|Ping]] for echo reachability and [[NMAP]] for service discovery.

**Source**
---
[Linux traceroute manual](https://man7.org/linux/man-pages/man8/traceroute.8.html)
