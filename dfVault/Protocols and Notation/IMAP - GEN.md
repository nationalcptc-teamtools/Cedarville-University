---
aliases:
  - "IMAP"
generated: true
sources_checked: 2026-10-23
---

# IMAP - GEN

IMAP accesses and manages mailboxes on a server. It supports message state and mailbox operations rather than simply treating retrieval as a one-time download.

**Example commands**
---
```text
a1 CAPABILITY
a2 LOGIN example-user example-password
a3 SELECT INBOX
a4 LOGOUT
```

Tags such as `a1` associate command completion replies with requests. Authentication and connection protection must be appropriate to the server; the plaintext example illustrates command structure only.

IMAP conventionally uses port 143, while implicit TLS IMAP uses port 993. Compare with [[Protocols and Notation/POP3 - GEN|POP3]] for another access protocol and [[Protocols and Notation/SMTP - GEN|SMTP]] for message transfer.

**Sources**
---
- [RFC 9051: IMAP4rev2](https://www.rfc-editor.org/info/rfc9051/)
- [RFC 8314: TLS for mail access](https://datatracker.ietf.org/doc/html/rfc8314)
