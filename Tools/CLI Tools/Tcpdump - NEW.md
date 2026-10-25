---
review_status: new
---

# Tcpdump

Tcpdump captures and displays network packets from the command line.

```bash
sudo tcpdump port 110 -A
```

`port 110` selects traffic using the POP3 port. `-A` prints payload bytes as ASCII. Capture privileges may require elevation.

An unencrypted POP3 authentication exchange can expose `USER` and `PASS` commands directly in the capture. TLS changes what a passive observer can read; packet visibility also depends on capture location and network topology.
