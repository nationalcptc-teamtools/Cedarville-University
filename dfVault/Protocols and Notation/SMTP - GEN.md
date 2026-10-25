---
aliases:
  - "SMTP"
generated: true
sources_checked: 2026-10-23
---

# SMTP - GEN

SMTP transfers email through mail submission and transfer services. TCP port 25 is the conventional SMTP relay port.

**Basic exchange**
---
```text
EHLO client.example
MAIL FROM:<sender@example.com>
RCPT TO:<recipient@example.net>
DATA
Subject: Example

Message body.
.
QUIT
```

The server replies with status codes. A line containing only a period terminates the message data.

Mail submission and mailbox access are distinct roles. [[Protocols and Notation/POP3 - GEN|POP3]] and [[Protocols and Notation/IMAP - GEN|IMAP]] retrieve or access stored mail. Implicit TLS submission conventionally uses port 465; this is different from SMTP relay on port 25.

**Sources**
---
- [RFC 5321: SMTP](https://www.rfc-editor.org/info/rfc5321/)
- [RFC 8314: TLS for submission and mail access](https://datatracker.ietf.org/doc/html/rfc8314)
