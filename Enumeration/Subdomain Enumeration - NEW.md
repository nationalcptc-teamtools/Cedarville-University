---
review_status: new
---

# Subdomain Enumeration

Subdomain enumeration discovers names associated with a domain. DNS discovery and HTTP virtual host discovery are related but distinct activities.

## Public sources

Certificate transparency logs can reveal current and historical certificate names. Search engines, public repositories, and archived pages provide additional leads. Sublist3r automates collection from public information sources.

```text
site:example.com -site:www.example.com
```

## DNS candidates

Wordlist-based DNS enumeration tries labels such as `admin.example.com`. Tools such as dnsrecon and Gobuster automate queries. Compare results with random labels to identify wildcard DNS and validate returned addresses.

## Virtual hosts

A web server can route several sites by the HTTP `Host` header. A site may be reachable this way even if its name is absent from public DNS.

```bash
ffuf -w /path/to/subdomains.txt -H 'Host: FUZZ.example.com' -u http://192.0.2.10/
ffuf -w /path/to/subdomains.txt -H 'Host: FUZZ.example.com' -u http://192.0.2.10/ -fs BASELINE_SIZE
```

Determine `BASELINE_SIZE` from the server's ordinary response to an unknown host. Validate differences manually rather than assuming that every varying response identifies a site.

Local hosts files map names to addresses for a particular machine: `/etc/hosts` on common Unix systems and `C:\Windows\System32\drivers\etc\hosts` on Windows. Such a mapping does not create a public DNS record.
