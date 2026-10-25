ICMP (Internet Control Message Protocol) is a [[Architecture/Network Layer - GEN|Network Layer]] protocol used to communicate error messages and operation information between the server and the client about IP network communication.

ICMP is used for [[Tools/CLI Tools/Ping - GEN|Ping]], and [[Tools/CLI Tools/Traceroute - GEN|Traceroute]].

ICMP is primarily used for diagnostics and network management, since it is encapsulated inside IP packets and does not carry application data.

ICMP has many types. [[Tools/CLI Tools/Ping - GEN|Ping]] uses Type 8 (Echo) and Type 0 (Echo Reply).