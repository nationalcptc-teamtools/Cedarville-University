---
review_status: new
---

# Browser Developer Tools

Browser developer tools expose the rendered document, JavaScript execution, network traffic, and client-side storage.

## Inspector

The Inspector displays the live DOM after JavaScript, CSS, and user actions have affected the page. It can reveal elements hidden by presentation rules and allows local edits for testing. A local DOM change does not itself bypass server-side authorization.

## Debugger or Sources

Inspect JavaScript files, set breakpoints, and follow execution. Endpoint paths, feature flags, validation logic, and comments can suggest further tests.

## Network

Record requests while navigating and submitting forms. Inspect methods, URLs, headers, cookies, bodies, responses, and background AJAX calls. Clear or filter the log to isolate a specific action.

## Storage

Inspect cookies, local storage, and session storage for authentication state, identifiers, preferences, and potentially exposed data. Client-controlled values must not be treated as authoritative by the server.

Page source shows the received HTML; Inspector shows the current DOM. Both views are useful and may differ substantially.
