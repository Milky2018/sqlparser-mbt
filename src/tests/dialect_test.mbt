///|
/// Test cases demonstrating different SQL dialect behaviors through parsing

///|  
test "MySQL SHOW statement parsing works" {
  // Test MySQL-specific SHOW statements using the default MySQL dialect
  let show_tables = @sqlparser.parse_sql("SHOW TABLES;")
  let show_columns = @sqlparser.parse_sql("SHOW COLUMNS FROM users;")
  let show_with_like = @sqlparser.parse_sql("SHOW TABLES LIKE 'user%';")
  
  // All should parse successfully
  inspect(show_tables.stmts.length(), content="1")
  inspect(show_columns.stmts.length(), content="1") 
  inspect(show_with_like.stmts.length(), content="1")
}

///|
test "MySQL backtick identifier support works" {
  // Test MySQL's backtick identifier support
  let backtick_sql = @sqlparser.parse_sql("SELECT * FROM `table name`;")
  inspect(backtick_sql.stmts.length(), content="1")
  
  // Test pretty printing preserves backticks
  let stmt = backtick_sql.stmts[0] |> @sqlparser.pretty_print
  inspect(stmt, content="SELECT\n  *\nFROM\n  `table name`;")
}

///|
test "Basic SELECT statement works" {
  // Test basic SELECT statement with FROM clause
  let select_sql = @sqlparser.parse_sql("SELECT 1 FROM dual;")
  inspect(select_sql.stmts.length(), content="1")
}

test "SELECT FROM statement works" {
  // Test SELECT with FROM clause
  let select_from = @sqlparser.parse_sql("SELECT * FROM users;")
  inspect(select_from.stmts.length(), content="1")
}