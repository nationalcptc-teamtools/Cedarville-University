When designing APIs, make sure that security is considered from the beginning.

Secure documentation if the API is not intended to be publicly accessible.

Ensure private documentation is kept updated so legitimate testers have full visibility of the API's attack surface.

Apply an allowlist of permitted HTTP methods

Validate that content type is expected for each request or response

Use generic error messages to avoid leaking information to attackers

Use protective measures on all versions of the API, not just the current production version.


To prevent mass assignment vulnerabilities, allowlist the properties that can be updated by the user and blocklist sensitive properties that shouldn't' be updated by the suer.

