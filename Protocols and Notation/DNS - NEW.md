---
review_status: new
---

# DNS

The Domain Name System maps names to records such as IP addresses, mail exchangers, and authoritative name servers. DNS information supports service discovery and reconnaissance.

## Record types

| Type | Purpose |
| --- | --- |
| A | IPv4 address |
| AAAA | IPv6 address |
| CNAME | Alias to another name |
| MX | Mail exchanger and priority |
| NS | Authoritative name server |
| SOA | Zone authority and administrative information |
| TXT | Text data, including verification and policy records |

## Queries

```bash
nslookup example.com
nslookup -type=MX example.com
nslookup -type=TXT example.com 1.1.1.1
dig example.com A
dig example.com MX
dig @1.1.1.1 example.com TXT
```

`nslookup` accepts a name, optional query type, and optional DNS server. `dig` displays detailed sections, record TTLs, and response metadata; `@SERVER` selects a resolver.

Multiple MX records can have different priorities. A non-authoritative answer generally comes from a recursive resolver rather than directly from the zone's authoritative server.

## Enumeration

Collect related names and addresses, then validate their relevance. Public records may omit internal or development names. Wildcard DNS can make arbitrary candidate labels resolve, so compare candidate answers with random labels.

DNS results identify naming and resolution behavior. They do not establish that an HTTP virtual host exists or that the corresponding application is reachable.
