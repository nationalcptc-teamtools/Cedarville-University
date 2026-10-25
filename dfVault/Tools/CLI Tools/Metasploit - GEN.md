---
aliases:
  - "Metasploit"
generated: true
sources_checked: 2026-10-23
---

# Metasploit - GEN

Metasploit Framework organizes security testing around modules. `msfconsole` provides its interactive console.

**Module types**
---
- Auxiliary: Discovery and other supporting operations.
- Exploit: Uses a vulnerability to reach a target consequence.
- Payload: Code or functionality delivered through an applicable path.
- Post: Operations performed through an existing session.

```text
search PRODUCT
use MODULE
show options
show payloads
```

Inspect required options and the selected module's behavior. Module selection alone does not verify that a target is affected.

Use it during [[Methodology/Exploitation - GEN|Exploitation]] and [[Methodology/Post Exploitation - GEN|Post Exploitation]]. [[NMAP]] can supply earlier service-discovery evidence.

**Source**
---
[Metasploit: Running modules](https://docs.metasploit.com/docs/using-metasploit/basics/using-metasploit.html)
