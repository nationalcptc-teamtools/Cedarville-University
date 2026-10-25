---
review_status: new
---

# FTP

The File Transfer Protocol transfers files between a client and server. Its control connection conventionally uses TCP port 21. Separate data connections carry listings and file content.

## Control commands

| Command | Purpose |
| --- | --- |
| `USER` | Supply a username |
| `PASS` | Supply a password |
| `SYST` | Query system type |
| `PASV` | Request passive data connection information |
| `TYPE A` | Select ASCII transfer mode |
| `STAT` | Request status |
| `QUIT` | End the session |

```text
USER example-user
PASS example-password
SYST
PASV
TYPE A
STAT
QUIT
```

An FTP client provides higher-level commands such as `ls`, `get FILE`, `ascii`, and `exit`. Choose transfer mode appropriately; text conversion can corrupt binary content.

## Security

Unprotected FTP sends credentials and data in cleartext. FTPS adds TLS to FTP. SFTP is a distinct file-transfer protocol carried over SSH, rather than FTP with a different encryption option.

FTP server examples include vsftpd and ProFTPD. A banner suggests software identity, but configuration and implementation must be validated independently.
