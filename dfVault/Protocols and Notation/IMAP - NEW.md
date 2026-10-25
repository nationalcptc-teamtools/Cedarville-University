---
review_status: new
---

# IMAP

IMAP accesses server-held mailboxes and synchronizes message state across clients. Plain IMAP conventionally uses TCP port 143; implicit TLS IMAP uses port 993.

## Example commands

```text
c1 LOGIN example-user example-password
c2 LIST "" "*"
c3 EXAMINE INBOX
c4 LOGOUT
```

Commands carry tags such as `c1` so that replies can be matched to their requests. `LIST` discovers mailboxes; `EXAMINE` opens a mailbox read-only. Other operations support message selection, retrieval, and state management.

## Security

A plaintext `LOGIN` exchange exposes credentials. TLS is required to protect the transport from passive reading and unauthorized modification. IMAP's server-side synchronization model differs from a basic download-oriented POP3 workflow.
