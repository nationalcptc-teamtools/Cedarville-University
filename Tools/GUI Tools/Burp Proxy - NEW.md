---
review_status: new
---

# Burp Proxy

Burp Proxy sits between a browser and a web server. It records HTTP and WebSocket traffic and can hold requests or responses for inspection and modification.

## Browser configuration

Burp's embedded browser is preconfigured to use the proxy. An external browser can use a manual proxy configuration or a profile managed by an extension such as FoxyProxy.

Typical local listener settings are:

| Setting | Value |
| --- | --- |
| Proxy address | `127.0.0.1` |
| Proxy port | `8080` |

For HTTPS interception, the external browser must trust the appropriate Burp CA certificate. Use a browser profile dedicated to testing.

## Interception and history

With interception enabled, a matching request waits until it is forwarded, dropped, or otherwise handled. An apparently stalled browser can therefore indicate a request waiting in Burp.

Turning interception off allows traffic to continue without pausing; it does not necessarily stop history logging. HTTP history and WebSocket history support later review and sending messages to other tools.

Right-click a captured request to send it to Repeater, Intruder, Decoder, or another component.

## Scope and rules

Add target hosts to the project scope, then configure interception rules to match in-scope URLs. Decide separately whether to retain out-of-scope history.

Response interception can be enabled for individual requests or by rules. Match-and-replace rules can modify headers, cookies, user agents, and message content; regular expressions support conditional replacements.

## Browser sandboxing

Running the embedded Chromium browser under an elevated account can cause sandbox startup problems. Running Burp under a normal user account preserves the browser's security boundary. A no-sandbox setting changes that boundary and should not be treated as the default configuration.
