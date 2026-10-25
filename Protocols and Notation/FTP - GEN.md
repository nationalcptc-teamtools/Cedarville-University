---
aliases:
  - "FTP"
generated: true
sources_checked: 2026-10-23
---

# FTP - GEN

FTP transfers files through a control connection and separate data connections. The control service conventionally listens on TCP port 21.

**Control commands**
---
- `USER` and `PASS`: Supply credentials.
- `TYPE`: Select representation type.
- `PASV`: Request passive data-connection information.
- `LIST`: Request a directory listing.
- `RETR`: Retrieve a file.
- `STOR`: Store a file.
- `QUIT`: End the session.

The data channel is separate from the command/reply exchange. Transfer mode and connection setup therefore affect how the client accesses files.

[[Tools/CLI Tools/TELNET - GEN|TELNET]] or [[Tools/CLI Tools/Netcat - GEN|Netcat]] can help inspect plaintext control exchanges. [[Protocols and Notation/SSH - GEN|SSH]] provides a different architecture for secure remote access and related file transfer.

**Source**
---
[RFC 959: File Transfer Protocol](https://www.rfc-editor.org/info/rfc959/)
