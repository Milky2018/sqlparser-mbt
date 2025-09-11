///|
/// Comprehensive SQL dialect tests ported from datafusion-sqlparser-rs
/// Focuses on MySQL dialect features since it's the default dialect

// ===== MySQL SHOW Statement Tests (ported from datafusion) =====

///|
test "MySQL SHOW TABLES statement" {
  let sql = @sqlparser.parse_sql("SHOW TABLES;")
  inspect(sql.stmts.length(), content="1")
  let pretty = sql.stmts[0] |> @sqlparser.pretty_print
  inspect(pretty, content="SHOW TABLES;")
}

///|
test "MySQL SHOW COLUMNS with FROM" {
  let sql = @sqlparser.parse_sql("SHOW COLUMNS FROM users;")
  inspect(sql.stmts.length(), content="1")
  let pretty = sql.stmts[0] |> @sqlparser.pretty_print
  inspect(pretty, content="SHOW COLUMNS FROM users;")
}

///|
test "MySQL SHOW TABLES with LIKE filter" {
  let sql = @sqlparser.parse_sql("SHOW TABLES LIKE 'user%';")
  inspect(sql.stmts.length(), content="1")
  let pretty = sql.stmts[0] |> @sqlparser.pretty_print
  inspect(pretty, content="SHOW TABLES LIKE 'user%';")
}

///|
test "MySQL SHOW STATUS statement" {
  let sql = @sqlparser.parse_sql("SHOW STATUS;")
  inspect(sql.stmts.length(), content="1")
  let pretty = sql.stmts[0] |> @sqlparser.pretty_print
  inspect(pretty, content="SHOW STATUS;")
}

///|
test "MySQL SHOW DATABASES statement" {
  let sql = @sqlparser.parse_sql("SHOW DATABASES;")
  inspect(sql.stmts.length(), content="1")
  let pretty = sql.stmts[0] |> @sqlparser.pretty_print
  inspect(pretty, content="SHOW DATABASES;")
}

// ===== MySQL Backtick Identifier Tests (ported from datafusion) =====

///|
test "MySQL backtick quoted table names" {
  let sql = @sqlparser.parse_sql("SELECT * FROM `table name`;")
  inspect(sql.stmts.length(), content="1")
  let pretty = sql.stmts[0] |> @sqlparser.pretty_print
  inspect(pretty, content="SELECT\n  *\nFROM\n  `table name`;")
}

///|
test "MySQL backtick quoted column names" {
  let sql = @sqlparser.parse_sql(
    "SELECT `column name`, `another col` FROM users;",
  )
  inspect(sql.stmts.length(), content="1")
}

///|
test "MySQL backtick quoted database.table" {
  let sql = @sqlparser.parse_sql("SELECT * FROM `my db`.`my table`;")
  inspect(sql.stmts.length(), content="1")
  let pretty = sql.stmts[0] |> @sqlparser.pretty_print
  inspect(pretty, content="SELECT\n  *\nFROM\n  `my db`.`my table`;")
}

///|
test "MySQL mixed quoted and unquoted identifiers" {
  let sql = @sqlparser.parse_sql("SELECT id, `full name` FROM users;")
  inspect(sql.stmts.length(), content="1")
}

///|
test "MySQL backtick with spaces in WHERE clause" {
  let sql = @sqlparser.parse_sql(
    "SELECT * FROM users WHERE `first name` = 'John';",
  )
  inspect(sql.stmts.length(), content="1")
}

///|
test "MySQL complex backtick identifiers" {
  let sql = @sqlparser.parse_sql(
    "SELECT `user-id`, `total.amount`, `my column` FROM `my-database`.`user-table`;",
  )
  inspect(sql.stmts.length(), content="1")
}

// ===== MySQL String Literal Tests (ported from datafusion) =====

///|
test "MySQL string literal with backslash escapes" {
  let sql = @sqlparser.parse_sql("SELECT 'It\\'s working' FROM dual;")
  inspect(sql.stmts.length(), content="1")
}

///|
test "MySQL string literal with escaped quotes" {
  let sql = @sqlparser.parse_sql("SELECT 'Say \"hello\" world' FROM dual;")
  inspect(sql.stmts.length(), content="1")
}

///|
test "MySQL string literal with escaped backslashes" {
  let sql = @sqlparser.parse_sql(
    "SELECT 'Path: C:\\\\Users\\\\name' FROM dual;",
  )
  inspect(sql.stmts.length(), content="1")
}

// ===== MySQL SHOW with Complex Filters Tests =====

///|
test "MySQL SHOW COLUMNS with complex table name" {
  let sql = @sqlparser.parse_sql("SHOW COLUMNS FROM `user data`;")
  inspect(sql.stmts.length(), content="1")
  let pretty = sql.stmts[0] |> @sqlparser.pretty_print
  inspect(pretty, content="SHOW COLUMNS FROM `user data`;")
}

///|
test "MySQL SHOW TABLES with complex pattern" {
  let sql = @sqlparser.parse_sql("SHOW TABLES LIKE 'test_%_data';")
  inspect(sql.stmts.length(), content="1")
  let pretty = sql.stmts[0] |> @sqlparser.pretty_print
  inspect(pretty, content="SHOW TABLES LIKE 'test_%_data';")
}

// ===== Core SQL Functionality Tests =====

///|
test "Standard SELECT with various clauses" {
  let sql = @sqlparser.parse_sql(
    "SELECT DISTINCT id, name FROM users WHERE id > 10 ORDER BY name LIMIT 5;",
  )
  inspect(sql.stmts.length(), content="1")
}

///|
test "CREATE TABLE with various data types" {
  let sql = @sqlparser.parse_sql(
    "CREATE TABLE users (id INTEGER, name VARCHAR(50), created_at TIMESTAMP);",
  )
  inspect(sql.stmts.length(), content="1")
}

///|
test "INSERT statement with values" {
  let sql = @sqlparser.parse_sql(
    "INSERT INTO users (id, name) VALUES (1, 'John'), (2, 'Jane');",
  )
  inspect(sql.stmts.length(), content="1")
}

///|
test "UPDATE statement with WHERE clause" {
  let sql = @sqlparser.parse_sql(
    "UPDATE users SET name = 'Updated Name' WHERE id = 1;",
  )
  inspect(sql.stmts.length(), content="1")
}

///|
test "DELETE statement with WHERE clause" {
  let sql = @sqlparser.parse_sql("DELETE FROM users WHERE id = 1;")
  inspect(sql.stmts.length(), content="1")
}

// ===== MySQL Boolean Literal Tests =====

///|
test "MySQL boolean literals in SELECT" {
  let sql = @sqlparser.parse_sql("SELECT TRUE, FALSE FROM dual;")
  inspect(sql.stmts.length(), content="1")
}

///|
test "MySQL boolean literals in WHERE" {
  let sql = @sqlparser.parse_sql("SELECT * FROM users WHERE active = TRUE;")
  inspect(sql.stmts.length(), content="1")
}
