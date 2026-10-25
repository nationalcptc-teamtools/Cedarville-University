---
review_status: new
---

# SMTP

SMTP transfers email between submission and mail transfer services. TCP port 25 is conventionally used for server-to-server SMTP.

## Mail delivery components

| Component | Role |
| --- | --- |
| Mail User Agent, MUA | The user's email client |
| Mail Submission Agent, MSA | Accepts outgoing messages from a client |
| Mail Transfer Agent, MTA | Relays messages to another mail server |
| Mail Delivery Agent, MDA | Delivers messages into a mailbox |

A message generally travels from the sender's MUA to an MSA/MTA, then to the recipient's MTA and MDA. The recipient accesses the mailbox through a protocol such as POP3 or IMAP. Several roles may run on one server.

## Basic exchange

```text
HELO client.example
MAIL FROM:<sender@example.com>
RCPT TO:<recipient@example.net>
DATA
Subject: Example message

Message body.
.
QUIT
```

A line containing only a period terminates the message data. Replies provide status codes describing acceptance or failure.

## Security

An SMTP exchange without TLS can expose message content and any plaintext authentication. TLS-protected transport and appropriate authentication help protect the connection, but do not by themselves provide end-to-end message confidentiality.
