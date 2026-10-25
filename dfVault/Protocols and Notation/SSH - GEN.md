---
aliases:
  - "SSH"
generated: true
sources_checked: 2026-10-23
---

# SSH - GEN

SSH provides secure remote login and other network services over an insecure network.

**Protocol components**
---
- Transport: Server authentication, confidentiality, and integrity.
- User authentication: Authenticates the client-side user.
- Connection: Multiplexes logical channels over the protected connection.

Server authentication and user authentication answer different questions. Establishing an encrypted channel alone does not establish that the intended server has been contacted.

Use SSH instead of treating [[Tools/CLI Tools/TELNET - GEN|TELNET]] as a protected terminal service. [[Linux Users]] and [[Linux CLI Commands/su - GEN|su]] concern account context on the operating system rather than the SSH protocol's entire security boundary.

**Source**
---
[RFC 4251: SSH architecture](https://www.rfc-editor.org/info/rfc4251/)
