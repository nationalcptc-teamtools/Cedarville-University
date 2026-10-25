---
aliases:
  - "Netcat"
generated: true
sources_checked: 2026-10-23
---

# Netcat - GEN

Netcat (`nc`) opens connections and listeners for [[TCP]], [[UDP]], and supported local sockets. It can inspect service behavior and exchange data interactively.

The following examples use OpenBSD Netcat syntax:

```bash
nc example.com 80
nc -l 1234
nc -u example.com 1234
```

| Option | Purpose |
| --- | --- |
| `-l` | Listen |
| `-u` | Use UDP |
| `-n` | Avoid name resolution |
| `-v` | Verbose output |
| `-w N` | Connection or idle timeout where applicable |

Netcat implementations have different option meanings. In particular, do not assume that a listener command copied from another implementation will work unchanged.

Compare with [[Tools/CLI Tools/TELNET - GEN|TELNET]] for plaintext protocol interaction and [[Protocols and Notation/SSH - GEN|SSH]] for authenticated remote administration.

**Source**
---
[OpenBSD nc manual](https://man.openbsd.org/nc)
