Structured Query Language defines and queries data in relational databases. Tables contain rows and named columns; queries select or modify those records.

## SELECT, filtering, and limits

```sql
SELECT * FROM users;
SELECT username,email FROM users WHERE username='admin';
SELECT * FROM users WHERE username!='admin';
SELECT * FROM users WHERE username='admin' OR username='analyst';
SELECT * FROM users WHERE username='admin' AND active=1;
SELECT * FROM users LIMIT 1;
```

`*` selects all columns. `WHERE` filters rows. `AND` requires both conditions; `OR` accepts either. Operator precedence and parentheses matter. `LIMIT` syntax and supported features vary by database engine.

## Pattern matching

```sql
SELECT * FROM users WHERE username LIKE 'a%';
SELECT * FROM users WHERE username LIKE '%n';
SELECT * FROM users WHERE username LIKE '%mi%';
```

`%` matches a sequence of characters in a LIKE pattern. Wildcards are interpreted by the database rather than as literal characters.

## Combining results

```sql
SELECT name,email FROM customers
UNION
SELECT name,email FROM suppliers;
```

UNION combines compatible result sets. The queries must return a matching number of columns with compatible types. UNION ALL retains duplicates.

## Data modification

```sql
INSERT INTO users (username,email) VALUES ('analyst','analyst@example.com');
UPDATE users SET email='new@example.com' WHERE username='analyst';
DELETE FROM users WHERE username='analyst';
```

An UPDATE or DELETE without a restricting condition can affect every row. Separate query structure from application input through parameterized queries. Dynamic identifiers such as sort-column names often require an explicit allowlist rather than value binding.
