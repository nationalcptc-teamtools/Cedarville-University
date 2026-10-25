---
review_status: new
---

# Nginx

Nginx commonly serves static content, proxies requests, and balances traffic. Its configuration determines which files and upstream services are reachable.

## Identification

Headers and default error pages can expose Nginx and a version. The `server_tokens` setting affects version disclosure, but changing it does not fix an underlying configuration weakness.

## Directory listing

```nginx
location /files/ {
    autoindex on;
    root /var/www/nginx;
}
```

Autoindex can intentionally publish a directory listing. The security concern is exposing material beyond its intended audience, particularly backups, deployment notes, or configuration files.

## Status endpoint

```nginx
location /nginx_status {
    stub_status;
    allow 127.0.0.1;
    deny all;
}
```

Stub status reports active connections, accepted and handled connections, request counts, and reading/writing/waiting state. Restrict its audience according to operational requirements.

## Assessment

Inspect relevant ports and locations, compare direct and proxied behavior, review exposed files, and evaluate security headers on the responses actually received. Record the affected location and consequence rather than treating every visible version or status page as equally severe.
