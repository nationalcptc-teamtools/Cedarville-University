A port is a networking construct that a computer uses to receive a connection. Network connections are made between two ports - an open port listening on the server and a randomly selected port on the client computer.

Every computer has a total of 65535 available ports. 1024 of these are standard ports reserved for regular services.


Standard Ports

| Protocol   | Default Port | Secured Protocol | Default Port with [[TLS]] |
| ---------- | ------------ | ---------------- | ------------------------- |
| [[Protocols and Notation/HTTP - GEN\|HTTP]]   | 80           | HTTPS            | 443                       |
| [[Protocols and Notation/FTP - GEN\|FTP]]    | 21           | FTPS             | 990                       |
| [[Protocols and Notation/SMTP - GEN\|SMTP]]   | 25           | SMTPS            | 465                       |
| [[Protocols and Notation/POP3 - GEN\|POP3]]   | 110          | POP3S            | 995                       |
| [[Protocols and Notation/IMAP - GEN\|IMAP]]   | 143          | IMAPS            | 993                       |
| [[Tools/CLI Tools/TELNET - GEN\|TELNET]] | 23           | [[Protocols and Notation/SSH - GEN\|SSH]]          | 22                        |

Ports can generally be classified as open or closed.
- Open: service listening on that port
- Closed: no service listening on that port

Ports can also be filtered by a firewall, leaving them in an indeterminate state to a scanner.