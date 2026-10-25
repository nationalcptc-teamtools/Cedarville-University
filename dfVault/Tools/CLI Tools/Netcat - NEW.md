---
review_status: new
---

# Netcat

Netcat (`nc`) reads and writes network connections. It can act as a TCP or UDP client, listen for connections, inspect service banners, and carry interactive input and output.

## Client and listener

```bash
nc example.com 80
nc -lvnp 1234
```

A simple HTTP request can be entered after connecting:

```http
GET / HTTP/1.1
Host: example.com

```

HTTP headers end with an empty line. A response can reveal a service banner and protocol behavior.

## Options

| Option | Purpose |
| --- | --- |
| `-l` | Listen |
| `-p PORT` | Specify a local port where supported |
| `-n` | Avoid name resolution |
| `-v` / `-vv` | Increase verbosity |
| `-k` | Continue listening after a connection closes where supported |
| `-u` | Use UDP where supported |

Netcat implementations differ in syntax and supported flags. Binding low-numbered ports may require additional privileges. A connection confirms transport reachability, but application behavior still needs protocol-specific interpretation.
