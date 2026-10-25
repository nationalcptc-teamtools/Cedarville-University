---
review_status: new
---

# Traceroute

Traceroute estimates the network path to a destination by sending probes with controlled IP time-to-live values. Routers that discard an expired probe may return ICMP time-exceeded messages.

```bash
traceroute example.com
```

Windows commonly provides `tracert`; probe protocols and options vary by implementation.

## Interpretation

- Each responding hop supplies an address and timing observations.
- An asterisk indicates that a probe did not receive the expected response within the timeout.
- Missing replies can reflect filtering or rate limiting rather than a broken forwarding path.
- Different probes can follow different paths because of routing changes or load balancing.
- Reverse traffic may follow a different route.

Use the output as evidence about a particular probe sequence, not as a guaranteed complete map of network topology.
