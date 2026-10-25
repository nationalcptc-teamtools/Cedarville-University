---
review_status: new
---

# Gobuster

Gobuster uses wordlists to enumerate web paths, DNS names, and HTTP virtual hosts.

## Shared options

| Option | Purpose |
| --- | --- |
| `-w FILE` | Wordlist |
| `-t N` | Concurrent workers |
| `-o FILE` | Save results |
| `--delay DURATION` | Delay between requests |

Use `gobuster --help` and the selected mode's help for supported options. SecLists contains separate lists for web content and DNS names; choose a list suited to the target.

## Directory and file discovery

```bash
gobuster dir -u http://example.com -w /path/to/web-content.txt
gobuster dir -u http://example.com -w /path/to/web-content.txt -x php,txt,bak -t 20
```

| Option | Purpose |
| --- | --- |
| `-u URL` | Base URL |
| `-x EXTENSIONS` | File extensions to try |
| `-r` | Follow redirects |
| `-k` | Skip TLS certificate verification |
| `-s CODES` | Select status codes to report |

Inspect response lengths and baseline behavior. Soft 404 pages and redirects can produce misleading results. An HTTP 403 may justify further inspection but does not prove that a particular file or module exists.

## DNS enumeration

```bash
gobuster dns -d example.com -w /path/to/subdomains.txt
```

| Option | Purpose |
| --- | --- |
| `-d DOMAIN` | Domain to enumerate |
| `-i` | Show resolved addresses |
| `-r RESOLVER` | Select a resolver |
| `--wildcard` | Continue despite wildcard DNS behavior, where supported |

DNS enumeration tries candidate labels such as `admin.example.com`. Wildcard records can make nonexistent labels appear valid; compare results with random labels and other evidence.

## Virtual host enumeration

```bash
gobuster vhost -u http://example.com -w /path/to/subdomains.txt --append-domain
```

Virtual host enumeration varies the HTTP `Host` header. It can find sites routed by a web server even when they have no public DNS record. DNS enumeration and virtual host enumeration answer different questions.

The base hostname must resolve to the intended server. A local hosts entry can provide that mapping without changing public DNS. Avoid treating a hosts-file entry as evidence of a public DNS record.
