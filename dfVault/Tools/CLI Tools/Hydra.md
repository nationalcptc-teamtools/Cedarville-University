Hydra audits network authentication by trying supplied usernames and password candidates against supported services, including FTP, SSH, POP3, IMAP, SMTP, and HTTP authentication mechanisms.

## Syntax

```bash
hydra -l USERNAME -P /path/to/passwords.txt SERVER SERVICE
hydra -l USERNAME -P /path/to/passwords.txt ftp://SERVER
hydra -l USERNAME -P /path/to/passwords.txt SERVER ssh
```

| Option | Purpose |
| --- | --- |
| `-l USERNAME` | A single login name |
| `-P FILE` | A password wordlist |
| `-s PORT` | A nondefault service port |
| `-t N` | Concurrent connections |
| `-V` or `-vV` | Show attempted combinations and verbose details |
| `-d` | Debug output |

Choose a wordlist based on the account and environment. Service behavior, throttling, lockouts, network latency, and concurrency affect results. Stop when the required evidence has been established.

## Authentication attack concepts

- **Guessing:** Uses knowledge about an account to select likely values.
- **Dictionary attack:** Tries entries from a candidate list.
- **Exhaustive brute force:** Tries combinations across a defined character space.

Authentication factors include something known, something possessed, and a biometric characteristic. Defensive measures include strong password handling, throttling, lockout controls, multifactor authentication, and suitable key-based authentication. These controls must be considered when interpreting test behavior.
