///|
/// Test cases demonstrating different SQL dialect behaviors

///|
test "MySQL dialect backslash escape" {
  let mysql_dialect = MySQL::{}
  let postgres_dialect = Postgres::{}
  let sqlite_dialect = SQLite::{}
  
  // MySQL supports backslash escapes, PostgreSQL and SQLite do not
  inspect(
    mysql_dialect.supports_string_literal_backslash_escape(),
    content="true",
  )
  inspect(
    postgres_dialect.supports_string_literal_backslash_escape(),
    content="false",
  )
  inspect(
    sqlite_dialect.supports_string_literal_backslash_escape(),
    content="false",
  )
}

///|
test "PostgreSQL advanced features" {
  let postgres = Postgres::{}
  let mysql = MySQL::{}
  
  // PostgreSQL supports advanced aggregation features
  inspect(
    postgres.supports_filter_during_aggregation(),
    content="true",
  )
  inspect(
    postgres.supports_within_after_array_aggregation(),
    content="true",
  )
  
  // MySQL does not support these features
  inspect(
    mysql.supports_filter_during_aggregation(),
    content="false",
  )
  inspect(
    mysql.supports_within_after_array_aggregation(),
    content="false",
  )
}

///|
test "SQLite flexible column types" {
  let sqlite = SQLite::{}
  let postgres = Postgres::{}
  
  // SQLite allows CREATE TABLE without column types
  inspect(
    sqlite.requires_column_types_in_create_table(),
    content="false",
  )
  
  // PostgreSQL requires column types
  inspect(
    postgres.requires_column_types_in_create_table(),
    content="true",
  )
}

///|
test "Generic dialect permissiveness" {
  let generic = Generic::{}
  
  // Generic dialect supports all features
  inspect(
    generic.supports_string_literal_backslash_escape(),
    content="true",
  )
  inspect(
    generic.supports_boolean_literals(),
    content="true",
  )
  inspect(
    generic.supports_filter_during_aggregation(),
    content="true",
  )
  inspect(
    generic.supports_double_quoted_identifiers(),
    content="true",
  )
}

///|
test "ANSI SQL strict compliance" {
  let ansi = ANSI::{}
  
  // ANSI SQL is more restrictive
  inspect(
    ansi.supports_string_literal_backslash_escape(),
    content="false",
  )
  inspect(
    ansi.supports_if_not_exists(),
    content="false",
  )
  inspect(
    ansi.requires_column_types_in_create_table(),
    content="true",
  )
}

///|
test "Cloud database dialects" {
  let bigquery = BigQuery::{}
  let snowflake = Snowflake::{}
  let redshift = Redshift::{}
  
  // All cloud dialects support double quoted identifiers
  inspect(
    snowflake.supports_double_quoted_identifiers(),
    content="true",
  )
  inspect(
    redshift.supports_double_quoted_identifiers(),
    content="true",
  )
  
  // BigQuery has different identifier handling
  inspect(
    bigquery.supports_double_quoted_identifiers(),
    content="false",
  )
}

///|
test "Parsing with different dialects" {
  // Test that we can create different dialect instances and use them
  let mysql_stmt = parse_sql(dialect=MySQL::{}, "SELECT 1 FROM dual;")
  let postgres_stmt = parse_sql(dialect=Postgres::{}, "SELECT 1 FROM table1;")
  let generic_stmt = parse_sql(dialect=Generic::{}, "CREATE TABLE test (id INTEGER);")
  
  // All should parse successfully
  inspect(mysql_stmt.stmts.length(), content="1")
  inspect(postgres_stmt.stmts.length(), content="1") 
  inspect(generic_stmt.stmts.length(), content="1")
}