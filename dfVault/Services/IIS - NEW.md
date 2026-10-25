---
review_status: new
---

# Internet Information Services

IIS hosts web applications on Windows. Relevant components include HTTP request handling, application pools, worker processes, authentication, handlers, and optional modules such as WebDAV.

## Identification and architecture

Inspect `Server`, `X-Powered-By`, and any ASP.NET version headers. An IIS major version does not uniquely identify the Windows release or patch level. Application pool identity determines the permissions of executed application code.

## WebDAV and methods

```bash
curl -X OPTIONS http://example.com/ -sv
curl -X OPTIONS http://example.com/webdav/ -sv
```

`DAV` headers and methods such as PROPFIND, PROPPATCH, MKCOL, COPY, and MOVE suggest WebDAV capability. Advertised methods do not establish that anonymous users can execute them. Test relevant paths, authentication requirements, and actual permissions.

## Configuration checks

| Condition | Evidence to investigate |
| --- | --- |
| Directory listing | Accessible backups, logs, archives, or configuration files |
| Writable resources | Actual PUT, MOVE, or DELETE behavior and required identity |
| `web.config` exposure | Returned configuration contents, especially secrets |
| Verbose exceptions | Public stack traces and internal paths |
| `trace.axd` exposure | Accessible tracing data |
| TRACE handling | Whether the method is needed and what is returned |
| Excessive worker privileges | Application execution as an unnecessarily privileged account |
| Short-name disclosure | Distinguishable 8.3 filename probe responses |

For classic ASP.NET configuration, `customErrors` and trace settings affect diagnostic exposure. Their relevance depends on the application framework and deployment.

## Defensive priorities

Remove unnecessary modules and methods, enforce write permissions explicitly, separate writable content from executable handlers, protect configuration files, restrict diagnostics, and run application pools with appropriate least privilege.

Log unexpected write operations and newly introduced executable files. A writable path and an executable handler are distinct conditions that must be assessed together when evaluating upload impact.
