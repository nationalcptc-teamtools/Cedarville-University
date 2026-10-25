---
review_status: new
---

# Telnet

Telnet is a plaintext remote terminal protocol, conventionally served on TCP port 23. The `telnet` client can also connect to other TCP services for manual protocol inspection.

```bash
telnet SERVER 23
telnet example.com 80
```

## Manual HTTP inspection

```http
GET / HTTP/1.1
Host: example.com

```

Send an empty line after the headers. The response can expose a status code, server header, and body.

## Security properties

Telnet does not encrypt credentials or session content. SSH provides encrypted remote administration and server authentication. Telnet-based inspection is suitable for understanding plaintext services, but a successful TCP connection alone does not establish application authorization or security.
