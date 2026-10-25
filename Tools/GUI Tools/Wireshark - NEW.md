---
review_status: new
---

# Wireshark

Wireshark captures and analyzes network packets through a graphical interface. Tcpdump and Tshark provide related command-line workflows.

## Plaintext protocol inspection

Use a display filter such as `pop` to focus on POP3 traffic. Unencrypted authentication can reveal `USER` and `PASS` commands. Visibility depends on capture position, and TLS-protected payloads are not readable from an ordinary passive capture.

## Understanding scans

Packet captures can show ARP discovery, ICMP requests and replies, TCP handshakes, SYN scans, and UDP probes. Compare the scanner's reported state with the actual exchange.

A UDP probe to a closed port may produce ICMP destination unreachable, port unreachable: type 3, code 3. Silence does not distinguish an open UDP service from filtering.

Retain relevant packets and timestamps when a capture supports a finding. Separate observed protocol behavior from assumptions about application state.
