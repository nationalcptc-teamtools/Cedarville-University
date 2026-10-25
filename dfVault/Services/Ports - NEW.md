---
review_status: new
---

# Ports

TCP and UDP use 16-bit port numbers to identify communication endpoints. The two protocols have separate port spaces. Conventional assignments are useful starting points, but a service can listen on a nonstandard port.

| Port | Protocol or service | Typical transport protection |
| --- | --- | --- |
| 21/TCP | FTP control | Plaintext unless upgraded |
| 22/TCP | SSH, SCP, SFTP | Encrypted |
| 23/TCP | Telnet | Plaintext |
| 25/TCP | SMTP relay | Depends on TLS negotiation |
| 43/TCP | WHOIS | Plaintext |
| 53/UDP and TCP | DNS | Ordinary DNS is not encrypted |
| 80/TCP | HTTP | Plaintext |
| 110/TCP | POP3 | Plaintext unless upgraded |
| 143/TCP | IMAP | Plaintext unless upgraded |
| 443/TCP | HTTPS | TLS |
| 465/TCP | Implicit TLS mail submission | TLS |
| 990/TCP | Implicit FTPS control | TLS |
| 993/TCP | IMAPS | TLS |
| 995/TCP | POP3S | TLS |

Ports 0–1023 are conventionally described as well-known ports. Discovering an open port establishes reachability, not a verified service identity or a vulnerability. Use banners and application probes to identify the actual service.

## Related concepts

- [[TLS]]
- [[Protocols and Notation/HTTP - GEN|HTTP]]
- [[Protocols and Notation/FTP - GEN|FTP]]
- [[Protocols and Notation/SMTP - GEN|SMTP]]
- [[Protocols and Notation/POP3 - GEN|POP3]]
- [[Protocols and Notation/IMAP - GEN|IMAP]]
- [[Tools/CLI Tools/TELNET - GEN|TELNET]]
- [[Protocols and Notation/SSH - GEN|SSH]]
