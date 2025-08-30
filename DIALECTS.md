# SQL Dialects

This MoonBit SQL parser supports multiple SQL dialects, each with their own specific parsing behaviors and syntax support. The implementation is similar to [datafusion-sqlparser-rs](https://github.com/apache/datafusion-sqlparser-rs).

## Available Dialects

### Major Database Dialects

#### MySQL
- **String Escapes**: Supports backslash escapes in string literals (`\'`, `\"`, `\\`)
- **Boolean Literals**: Does not support `TRUE`/`FALSE` keywords
- **Double Quoted Identifiers**: Not supported (uses backticks instead)
- **Example**: `SELECT 'It\'s working' FROM \`table\`;`

#### PostgreSQL
- **Advanced Features**: Supports `FILTER` during aggregation and `WITHIN` after array aggregation
- **Double Quoted Identifiers**: Supported for case-sensitive identifiers
- **String Escapes**: Uses standard SQL string literals (no backslash escapes)
- **Example**: `SELECT count(*) FILTER (WHERE active) FROM "MyTable";`

#### SQLite
- **Flexible Schema**: Allows `CREATE TABLE` without specifying column types
- **Double Quoted Identifiers**: Supported
- **String Escapes**: No backslash escapes (uses doubled quotes: `'don''t'`)
- **Example**: `CREATE TABLE test (name, value);`

### Standard Compliance

#### ANSI SQL
- **Strict Compliance**: Follows ANSI SQL standards closely
- **No Extensions**: Does not support vendor-specific extensions like `IF NOT EXISTS`
- **Required Types**: Always requires column types in `CREATE TABLE`
- **Example**: Standard SQL only, no vendor extensions

### Cloud Database Dialects

#### BigQuery (Google Cloud)
- **Identifier Rules**: Different identifier quoting rules
- **String Escapes**: Supports backslash escapes
- **Standard Features**: Supports most standard SQL features

#### Snowflake
- **Enterprise Features**: Supports advanced data warehouse features
- **Case Sensitivity**: Supports double-quoted case-sensitive identifiers
- **String Escapes**: Supports backslash escapes

#### Redshift (Amazon)
- **Data Warehouse**: Optimized for analytics workloads
- **PostgreSQL Compatible**: Based on PostgreSQL with extensions
- **Double Quoted Identifiers**: Supported

### Analytics Database Dialects

#### ClickHouse
- **High Performance**: Optimized for analytical queries
- **String Escapes**: Supports backslash escapes
- **Column Types**: Requires explicit column types

#### DuckDB
- **PostgreSQL Compatible**: Follows PostgreSQL syntax closely
- **Advanced Features**: Supports modern SQL features
- **Flexible Schema**: Allows some schema flexibility

### Generic Dialect
- **Most Permissive**: Supports the union of all other dialects
- **Development**: Useful for parsing SQL from unknown sources
- **All Features**: Enables all parser features when there's no ambiguity

## Usage Examples

```moonbit
// Parse with specific dialects
let mysql_result = parse_sql(dialect=MySQL::{}, "SELECT 'don\\'t' FROM users;")
let postgres_result = parse_sql(dialect=Postgres::{}, "SELECT count(*) FILTER (WHERE active) FROM users;")
let sqlite_result = parse_sql(dialect=SQLite::{}, "CREATE TABLE test (name, value);")

// Use Generic dialect for maximum compatibility
let generic_result = parse_sql(dialect=Generic::{}, sql_from_unknown_source)
```

## Dialect Characteristics

| Feature | MySQL | PostgreSQL | SQLite | ANSI | Generic |
|---------|-------|------------|--------|------|---------|
| Backslash Escapes | ✅ | ❌ | ❌ | ❌ | ✅ |
| Boolean Literals | ❌ | ✅ | ✅ | ✅ | ✅ |
| Double Quoted IDs | ❌ | ✅ | ✅ | ✅ | ✅ |
| IF NOT EXISTS | ✅ | ✅ | ✅ | ❌ | ✅ |
| FILTER Aggregation | ❌ | ✅ | ❌ | ❌ | ✅ |
| Flexible Types | ❌ | ❌ | ✅ | ❌ | ✅ |

## Extending Dialects

To create a new dialect, implement the `Dialect` trait:

```moonbit
pub struct MyCustomDialect {}

impl Dialect for MyCustomDialect with supports_string_literal_backslash_escape(_self) {
  true  // Enable backslash escapes
}

impl Dialect for MyCustomDialect with supports_boolean_literals(_self) {
  false  // Disable TRUE/FALSE keywords
}

// ... implement other trait methods as needed
```

## Testing

The parser includes comprehensive dialect tests in `src/dialect_tests.mbt` that demonstrate the differences between dialects and verify correct parsing behavior.

Run tests with: `moon test`