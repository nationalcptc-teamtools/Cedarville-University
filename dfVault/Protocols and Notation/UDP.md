UDP (User Datagram Protocol) is a [[Architecture/Transport Layer - GEN|Transport Layer]] protocol which transmits data efficiently between computers.

UDP does not use a handshake to create a connection. Lost packets are not re-sent. UDP prioritizes transmission speed and efficiency, often used for time-sensitive applications.

The client initiates the connection by sending a **UDP** packet. If the port is open, the server sends no return packet. If the port is closed, the server returns a **ICMP** (Internet Control Message Protocol) packet.

Client --> **UDP** --> Server

(If closed) Server --> **ICMP** --> Client

The UDP protocol can be leveraged by scanning tools such as [[NMAP]] to determine whether a port is closed or not.