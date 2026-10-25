---
review_status: new
---

# POP3

POP3 retrieves email from a mailbox server. Unencrypted POP3 conventionally uses TCP port 110; implicit TLS POP3 uses port 995.

## Session commands

| Command | Purpose |
| --- | --- |
| `USER name` | Identify the account |
| `PASS password` | Authenticate |
| `STAT` | Return message count and total size |
| `LIST` | List messages and sizes |
| `RETR n` | Retrieve a message |
| `QUIT` | End the session |

```text
USER example-user
PASS example-password
STAT
LIST
RETR 1
QUIT
```

Positive replies begin with `+OK`. A successful `STAT` reply includes the message count and mailbox size in octets.

## Client behavior and security

Clients can download messages and may be configured to delete them from the server afterward. Retention behavior depends on the client and settings.

Without TLS, authentication and message content can be visible in a packet capture. A password not being echoed in a terminal does not imply that it is encrypted on the network.
