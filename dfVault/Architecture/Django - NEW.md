---
review_status: new
---

# Django

Django is a Python web framework with routing, templates, an ORM, authentication components, and middleware. It can run behind a production application server or its development server.

## Fingerprinting

Potential signals include the `/admin/` interface, a `csrftoken` cookie, a `csrfmiddlewaretoken` form field, Python-related server banners, and combinations of security headers. Any one signal may occur elsewhere; corroborate findings.

```bash
curl -I https://example.com/products/
```

## Ordering inputs and SQL

Applications often expose sorting through a parameter such as `order`. Interpolating that value directly into SQL is unsafe:

```python
order = request.GET.get('order', 'name')
sql = f'SELECT id, name, price FROM products_product ORDER BY {order}'
```

This is an application-level injection pattern. It should not automatically be attributed to a framework CVE. `CVE-2021-35042` is a separate version-specific Django ORM reference requiring verification of the affected API and installed version.

Choose the sort expression from a server-controlled allowlist. Parameterized values do not automatically make a user-supplied SQL identifier safe.

## Error handling

Debug responses can expose settings, SQL, filesystem paths, and dependency versions. Error-based SQL techniques depend on the database functions and configuration actually present; an expression copied from another environment is not portable evidence.

Keep detailed exceptions out of public responses, use a production deployment configuration, and validate authorization and input handling in application code.
