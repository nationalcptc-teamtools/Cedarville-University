---
review_status: new
---

# SSH

Secure Shell provides authenticated, encrypted remote access, conventionally over TCP port 22. It protects the confidentiality and integrity of session traffic.

```bash
ssh USER@SERVER
ssh USER@SERVER COMMAND
```

## Authentication

The client authenticates the server using its host key. Users can authenticate using a password or a configured key-based mechanism. Server identity checks matter because encryption to an impersonated endpoint does not establish the intended peer's identity.

## File transfer

SCP and SFTP provide file-transfer workflows associated with SSH. They are distinct from FTPS, which applies TLS to FTP.

## Assessment considerations

Record the server banner, supported authentication methods, exposed users where demonstrable, and applicable access restrictions. Evaluate credential handling, key management, and account privileges separately from the fact that the connection is encrypted.
