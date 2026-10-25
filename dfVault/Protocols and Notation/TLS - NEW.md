---
review_status: new
---

# TLS

Transport Layer Security protects application traffic through encryption, integrity checking, and peer authentication. It is the successor to SSL; the terms are sometimes used loosely, but obsolete SSL protocols should not be treated as equivalent to modern TLS.

## Connection establishment

For HTTPS over TCP, the conceptual sequence is:

1. Establish a TCP connection.
2. Negotiate TLS parameters and authenticate the server.
3. Exchange HTTP messages inside the protected connection.

The handshake begins with a ClientHello and ServerHello. Certificates and key-establishment messages allow the peers to derive shared traffic secrets. Exact messages differ between protocol versions; older descriptions involving ClientKeyExchange and ChangeCipherSpec do not describe every modern handshake.

## Key exchange models

In historical RSA key exchange, the client generated a premaster secret and encrypted it with the server certificate's public key. The server decrypted it with its private key, and both sides derived session keys from that secret and the client/server random values. Finished messages confirmed the handshake. This key exchange is absent from TLS 1.3.

Ephemeral Diffie–Hellman exchanges public parameters so both parties can compute a shared secret without transmitting that secret. Certificate-based signatures authenticate the exchange. Ephemeral key material supports forward secrecy when implemented and managed correctly.

TLS 1.3 includes key-share information early in the handshake and encrypts more of the negotiation. In a normal certificate-authenticated exchange, the server supplies authentication material and a Finished message, the client verifies them, and the client sends its Finished message. Do not substitute a legacy handshake diagram for the exact messages of a particular version.

## Session resumption and 0-RTT

Session tickets can enable a later connection to resume using previously established secret material. TLS 1.3 can permit early application data before the new handshake completes. This reduces latency but has replay considerations; early data is unsuitable for operations that cannot safely tolerate repetition without additional controls.

## Certificates and trust

Inspect the certificate's subject names, issuer, validity period, and trust chain. Successful verification requires a trusted chain and a name matching the intended endpoint. A certificate can be valid for one host and inappropriate for another.

## Protected protocols

| Service | Plaintext port | Conventional implicit TLS port |
| --- | --- | --- |
| HTTP / HTTPS | 80 | 443 |
| FTP / FTPS control | 21 | 990 |
| SMTP / implicit TLS submission | 25 for SMTP relay | 465 |
| POP3 / POP3S | 110 | 995 |
| IMAP / IMAPS | 143 | 993 |

Some protocols upgrade an existing connection using an explicit TLS negotiation rather than starting with TLS. Port numbers alone therefore do not establish whether a session is protected.

## Security interpretation

Proper certificate validation and protocol negotiation help prevent interception and message alteration. TLS does not correct application authorization failures, insecure endpoints, exposed backups, or weak server-side logic. Evaluate transport security and application security separately.

## Related concepts

- [[Architecture/Transport Layer - GEN|Transport Layer]]

## References

- [Further reading](https://www.cloudflare.com/learning/ssl/what-happens-in-a-tls-handshake/)
