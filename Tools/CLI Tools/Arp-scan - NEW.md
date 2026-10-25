---
review_status: new
---

# Arp-scan

Arp-scan discovers hosts on a local IPv4 network by sending [[ARP]] requests and recording replies. ARP does not traverse routers, so this method applies to the local broadcast domain.

```bash
sudo arp-scan --localnet
sudo arp-scan -l
sudo arp-scan -I eth0 -l
```

| Option | Purpose |
| --- | --- |
| `--localnet` or `-l` | Enumerate addresses on the local interface's network |
| `-I INTERFACE` | Select a network interface |

Use the interface connected to the network being assessed. Packet capture privileges may require elevation.

[Arp-scan user guide](https://github.com/royhills/arp-scan/wiki/arp-scan-User-Guide)
