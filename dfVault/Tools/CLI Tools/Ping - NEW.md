---
review_status: new
---

# Ping

Ping tests IP reachability and round-trip response time using [[ICMP]] echo requests and replies.

```bash
ping example.com
ping 192.0.2.10
ping -c 4 192.0.2.10
```

The `-c` count option is used by common Unix implementations; Windows uses different option syntax.

## Interpreting results

An echo reply shows that the target and return path handled the probe. Response time and packet loss help characterize connectivity.

No reply can result from filtering, routing failure, an offline target, a local connection problem, or a device configured not to answer echo requests. It is not conclusive evidence that the host is offline.

ICMP echo requests use type 8 and replies type 0 in IPv4. On a local Ethernet network, address resolution can precede the echo exchange.
