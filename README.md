# Extensible SQL Lexer and Parser for MoonBit

A comprehensive SQL parser library for MoonBit that supports multiple SQL dialects and all major SQL language categories.

## Features

### SQL Language Coverage

- **DML (Data Manipulation Language)**: `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `WITH` (CTEs)
- **DDL (Data Definition Language)**: `CREATE TABLE/VIEW`, `DROP TABLE/VIEW`, `ALTER TABLE`, `TRUNCATE`
- **TCL (Transaction Control Language)**: `BEGIN`, `START TRANSACTION`, `COMMIT`, `ROLLBACK`, `SAVEPOINT`, `RELEASE SAVEPOINT`
- **DCL (Data Control Language)**: `GRANT`, `REVOKE` with comprehensive privilege support
- **Utility Commands**: `SHOW`, `SET`, `EXPLAIN`, `ANALYZE`

### Supported SQL Dialects

- **MySQL**: `SHOW` statements, `SET` variables, `REPLACE INTO`, `ON DUPLICATE KEY UPDATE`, `LOCK/UNLOCK TABLES`
- **PostgreSQL**: Array syntax (`ARRAY[1,2,3]`, `[1,2,3]`), array subscripting, `LISTEN/NOTIFY`
- **SQLite**: Conflict resolution (`OR IGNORE`, `OR REPLACE`, etc.)
- **BigQuery**: Parameterized queries, nested structures
- **ClickHouse, DuckDB, Snowflake, Redshift**: Dialect-specific extensions

### Advanced Features

- **Common Table Expressions (CTEs)**: Full `WITH` clause support including recursive CTEs
- **Window Functions**: Advanced analytical functions
- **Complex Expressions**: Subqueries, case expressions, function calls
- **Join Support**: All join types (INNER, LEFT, RIGHT, FULL, CROSS) with ON/USING clauses
- **Aggregate Functions**: GROUP BY, HAVING, ORDER BY, LIMIT/OFFSET

## Example Usage

```moonbit
// Parse a simple SELECT statement
let sql = "SELECT name, age FROM users WHERE age > 18"
let statements = parse_sql(sql)
let pretty_output = statements.stmts[0] |> pretty_print
println(pretty_output)

// Parse complex queries with CTEs
let complex_sql = """
WITH sales AS (
  SELECT user_id, SUM(amount) as total
  FROM orders 
  WHERE date > '2023-01-01'
  GROUP BY user_id
)
SELECT u.name, s.total
FROM users u
JOIN sales s ON u.id = s.user_id
ORDER BY s.total DESC
LIMIT 10
"""
let result = parse_sql(complex_sql)

// Parse transaction control statements
let tcl_sql = "BEGIN TRANSACTION; INSERT INTO users VALUES ('Alice'); COMMIT;"
let tcl_statements = parse_sql(tcl_sql)

// Parse data control statements
let dcl_sql = "GRANT SELECT, INSERT ON users TO alice WITH GRANT OPTION"
let dcl_result = parse_sql(dcl_sql)

// Dialect-specific parsing
let mysql_sql = "SHOW TABLES LIKE 'user%'"
let mysql_result = parse_sql(dialect=MySQL::{}, mysql_sql)
```

## Architecture

The parser follows a modular design:

- **Lexer** (`lexer.mbt`): Tokenizes SQL input with dialect-aware keyword recognition
- **Parser** (`parser.mbt`): Main parsing logic with statement dispatching
- **AST** (`ast.mbt`): Complete Abstract Syntax Tree definitions with pretty printing
- **Dialect Modules**: Separate modules for each SQL dialect (`mysql.mbt`, `postgres.mbt`, etc.)
- **Language Modules**: 
  - `dml.mbt`: Data Manipulation Language parsing
  - `ddl.mbt`: Data Definition Language parsing  
  - `tcl.mbt`: Transaction Control Language parsing
  - `dcl.mbt`: Data Control Language parsing

## Testing

The library includes comprehensive test coverage with 220+ tests covering:

- All SQL statement types across all language categories
- Dialect-specific features and syntax variations
- Complex expressions and nested queries
- Edge cases and error handling
- Pretty printing accuracy

Run tests with:
```bash
moon test
```

## SQL Language Categories Supported

| Category | Statements | Status |
|----------|------------|--------|
| **DML** | SELECT, INSERT, UPDATE, DELETE, WITH | ✅ Complete |
| **DDL** | CREATE, DROP, ALTER, TRUNCATE | ✅ Complete |
| **TCL** | BEGIN, COMMIT, ROLLBACK, SAVEPOINT | ✅ Complete |
| **DCL** | GRANT, REVOKE | ✅ Complete |
| **Utility** | SHOW, SET, EXPLAIN, ANALYZE | ✅ Complete |

## Supported Privileges (DCL)

- **Table Privileges**: SELECT, INSERT, UPDATE, DELETE, REFERENCES
- **Schema Privileges**: CREATE, DROP, ALTER, INDEX
- **Special Privileges**: ALL PRIVILEGES, USAGE, EXECUTE, CONNECT, TEMPORARY
- **Column-Level**: SELECT(col1,col2), INSERT(col1), UPDATE(col1), REFERENCES(col1)
- **Grant Options**: WITH GRANT OPTION, GRANT OPTION FOR
- **Revoke Options**: RESTRICT, CASCADE

## Transaction Support (TCL)

- `BEGIN [WORK] [TRANSACTION]`
- `START TRANSACTION`
- `COMMIT [WORK] [TRANSACTION]` 
- `ROLLBACK [WORK] [TRANSACTION] [TO [SAVEPOINT] savepoint_name]`
- `SAVEPOINT savepoint_name`
- `RELEASE [SAVEPOINT] savepoint_name`

## Contributing

The parser is designed for extensibility. To add new SQL features:

1. Add keywords to `keyword.mbt` and `lexer.mbt`
2. Define AST structures in `ast.mbt` 
3. Implement parsing logic in appropriate language module
4. Add statement cases to `parser.mbt`
5. Write comprehensive tests

## License

This project is licensed under the Apache 2.0 License.
