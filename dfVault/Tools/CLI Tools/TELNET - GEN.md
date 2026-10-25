---
aliases:
  - "TELNET"
generated: true
sources_checked: 2026-10-23
---

# TELNET - GEN

Telnet defines a bidirectional terminal-oriented communication protocol. It uses a Network Virtual Terminal representation and negotiates options between peers.

Control commands are distinguished by an Interpret As Command byte. The conventional server port is TCP 23.

The base protocol does not supply the encrypted, authenticated transport architecture described by [[Protocols and Notation/SSH - GEN|SSH]]. Terminal-style interaction and connection security are separate properties.

[[Tools/CLI Tools/Netcat - GEN|Netcat]] provides a different general-purpose connection tool. [[Protocols and Notation/HTTP - GEN|HTTP]] can also be inspected through a suitable plaintext client when the service is not using TLS.

**Source**
---
[RFC 854: Telnet protocol](https://www.rfc-editor.org/info/rfc854/)
