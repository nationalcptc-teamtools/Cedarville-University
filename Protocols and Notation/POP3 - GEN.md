---
aliases:
  - "POP3"
generated: true
sources_checked: 2026-10-23
---

# POP3 - GEN

POP3 accesses messages in a maildrop. A session progresses through authorization, transaction, and update states.

**Commands**
---
- `USER` / `PASS`: Authenticate using the corresponding mechanism.
- `STAT`: Obtain message count and size.
- `LIST`: List messages and sizes.
- `RETR`: Retrieve a message.
- `DELE`: Mark a message for deletion.
- `QUIT`: End the session; update-state processing commits marked deletions.

Downloading a message is not the same operation as deleting it. Client behavior determines which commands are issued.

Plain POP3 conventionally uses port 110; implicit TLS POP3 uses port 995. [[Protocols and Notation/IMAP - GEN|IMAP]] provides a different mailbox-access model, while [[Protocols and Notation/SMTP - GEN|SMTP]] handles mail transfer.

**Sources**
---
- [RFC 1939: POP3](https://datatracker.ietf.org/doc/html/rfc1939)
- [RFC 8314: TLS for mail access](https://datatracker.ietf.org/doc/html/rfc8314)
