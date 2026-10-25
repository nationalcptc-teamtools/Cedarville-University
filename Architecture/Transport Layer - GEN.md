---
aliases:
  - "Transport Layer"
generated: true
sources_checked: 2026-10-23
---

# Transport Layer - GEN

The Transport Layer provides end-to-end communication services above the network layer. [[TCP]] and [[UDP]] provide different transport behavior.

- TCP provides an ordered, reliable byte stream.
- UDP provides datagrams without TCP's reliability mechanisms.
- [[Ports]] identify transport endpoints.

The Internet model places transport above IP. The [[Network Layers|OSI model]] describes transport as layer 4, below the [[Architecture/Session Layer - GEN|Session Layer]] and above the [[Architecture/Network Layer - GEN|Network Layer]].

**Sources**
---
- [RFC 1122: Internet host communication layers](https://datatracker.ietf.org/doc/html/rfc1122)
- [Cisco: TCP/IP overview](https://www.cisco.com/c/en/us/support/docs/ip/routing-information-protocol-rip/13769-5.html)
