///|
pub(all) struct MySQL {}

///|
pub impl Dialect for MySQL with supports_string_literal_backslash_escape(_self) {
  true
}

///|
pub impl Dialect for MySQL with supports_boolean_literals(_self) {
  true
}

///|
pub impl Dialect for MySQL with supports_filter_during_aggregation(_self) {
  false
}

///|
pub impl Dialect for MySQL with supports_within_after_array_aggregation(_self) {
  false
}

///|
pub impl Dialect for MySQL with requires_column_types_in_create_table(_self) {
  false
}

///|
pub impl Dialect for MySQL with supports_double_quoted_identifiers(_self) {
  false
}

///|
pub impl Dialect for MySQL with supports_if_not_exists(_self) {
  true
}

///|
pub impl Dialect for MySQL with read_keyword(_self : MySQL, word : String) -> Keyword? {
  match word {
    // MySQL-specific LOAD DATA keywords
    "load" => Some(Load)
    "data" => Some(Data)
    "local" => Some(Local)
    "infile" => Some(Infile)
    "fields" => Some(Fields)
    "lines" => Some(Lines)
    "terminated" => Some(Terminated)
    "enclosed" => Some(Enclosed)
    "escaped" => Some(Escaped)
    "starting" => Some(Starting)
    "optionally" => Some(Optionally)
    _ => None
  }
}

///|
pub impl Dialect for MySQL with parse_statement(
  _self : MySQL,
  parser : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[Statement]? raise ParserError {
  match tokens {
    [Keyword(Load), Keyword(Data), .. _rest] => {
      // MySQL LOAD DATA statement
      let (load_data_stmt, remaining_tokens) = parser.parse_load_data_statement(tokens)
      Some((Statement::LoadData(load_data_stmt), remaining_tokens))
    }
    [Keyword(Lock), Keyword(Tables), Identifier(table_name), Semicolon, .. rest] => {
      // MySQL LOCK TABLES statement
      let table = ObjectName::{ parts: [table_name] }
      Some((Statement::LockTables([table]), rest))
    }
    [Keyword(Unlock), Keyword(Tables), Semicolon, .. rest] => {
      // MySQL UNLOCK TABLES statement
      Some((Statement::UnlockTables, rest))
    }
    _ => None  // Fall back to generic parsing
  }
}

///|
pub impl Dialect for MySQL with parse_expr(
  _self : MySQL,
  _tokens : ArrayView[Token],
) -> ParserResult[Expr]? raise ParserError {
  // MySQL DIV operator needs to be parsed in the main parser as it's infix
  // For now, returning None to use the generic parsing
  None
}


///|

test "MySQL SHOW TABLES" {
  let tokens = "SHOW TABLES;"
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SHOW TABLES;
    ),
  )
}

///|
test "MySQL SHOW COLUMNS FROM table" {
  let tokens = "SHOW COLUMNS FROM users;"
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SHOW COLUMNS FROM users;
    ),
  )
}

///|
test "MySQL SHOW TABLES LIKE pattern" {
  let tokens = "SHOW TABLES LIKE 'user%';"
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SHOW TABLES LIKE 'user%';
    ),
  )
}

///|
test "MySQL with backticks in SHOW" {
  let tokens = "SHOW COLUMNS FROM `table name`;"
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SHOW COLUMNS FROM `table name`;
    ),
  )
}

///|
test "MySQL LOCK TABLES" {
  let tokens = "LOCK TABLES users;"
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|LOCK TABLES users;
    ),
  )
}

///|
test "MySQL UNLOCK TABLES" {
  let tokens = "UNLOCK TABLES;"
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|UNLOCK TABLES;
    ),
  )
}

///|
test "MySQL DIV operator" {
  let tokens = "SELECT 10 DIV 3 FROM test;"
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print  
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  10  DIV  3
      #|FROM
      #|  test;
    ),
  )
}

///|
test "MySQL SHOW VARIABLES" {
  let tokens = "SHOW VARIABLES;"
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SHOW VARIABLES;
    ),
  )
}

///|
test "MySQL SHOW GLOBAL STATUS" {
  let tokens = "SHOW GLOBAL STATUS;"
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SHOW GLOBAL STATUS;
    ),
  )
}

///|
test "MySQL SHOW FULL PROCESSLIST" {
  let tokens = "SHOW FULL PROCESSLIST;"
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SHOW FULL PROCESSLIST;
    ),
  )
}

///|
test "MySQL SHOW CREATE TABLE" {
  let tokens = "SHOW CREATE TABLE users;"
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SHOW CREATE TABLE users;
    ),
  )
}

///|
test "MySQL SHOW EXTENDED COLUMNS" {
  let tokens = "SHOW EXTENDED COLUMNS FROM users LIKE 'name%';"
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SHOW EXTENDED COLUMNS FROM users LIKE 'name%';
    ),
  )
}

///|
test "MySQL SET session variable" {
  let tokens = "SET SESSION sql_mode = 'STRICT_TRANS_TABLES';"
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SET SESSION sql_mode = 'STRICT_TRANS_TABLES';
    ),
  )
}

///|
test "MySQL SET global variable" {
  let tokens = "SET GLOBAL max_connections = 200;"
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SET GLOBAL max_connections = 200;
    ),
  )
}

///|
test "MySQL SET user variable" {
  let tokens = "SET @counter = 1;"
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SET @counter = 1;
    ),
  )
}

///|
test "MySQL SET multiple variables" {
  let tokens = "SET @name = 'John', @age = 30, @salary = 50000.50;"
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SET @name = 'John', @age = 30, @salary = 50000.5;
    ),
  )
}

///|
test "MySQL SET local variable" {
  let tokens = "SET autocommit = 0;"
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SET autocommit = 0;
    ),
  )
}

///|
test "MySQL REPLACE INTO statement" {
  let tokens = "REPLACE INTO users (id, name) VALUES (1, 'John');"
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|REPLACE INTO users (id, name) VALUES (1, 'John');
    ),
  )
}

///|
test "MySQL REPLACE INTO with multiple values" {
  let tokens = "REPLACE INTO products (id, name, price) VALUES (1, 'Widget', 10.50), (2, 'Gadget', 15.00);"
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|REPLACE INTO products (id, name, price) VALUES (1, 'Widget', 10.5), (2, 'Gadget', 15);
    ),
  )
}

///|
test "MySQL INSERT OR REPLACE statement" {
  let tokens = "INSERT OR REPLACE INTO settings (key, value) VALUES ('theme', 'dark');"
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|REPLACE INTO settings (key, value) VALUES ('theme', 'dark');
    ),
  )
}

///|
test "MySQL INSERT with ON DUPLICATE KEY UPDATE" {
  let tokens = "INSERT INTO users (id, name, email) VALUES (1, 'John', 'john@example.com') ON DUPLICATE KEY UPDATE name = 'John Updated', email = 'john.new@example.com';"
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|INSERT INTO users (id, name, email) VALUES (1, 'John', 'john@example.com') ON DUPLICATE KEY UPDATE name = 'John Updated', email = 'john.new@example.com';
    ),
  )
}

///|
test "MySQL INSERT single assignment ON DUPLICATE KEY UPDATE" {
  let tokens = "INSERT INTO counters (id, count) VALUES (1, 1) ON DUPLICATE KEY UPDATE count = count + 1;"
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|INSERT INTO counters (id, count) VALUES (1, 1) ON DUPLICATE KEY UPDATE count = count + 1;
    ),
  )
}

///|
test "MySQL REPLACE with ON DUPLICATE KEY UPDATE" {
  let tokens = "REPLACE INTO settings (setting_key, setting_value) VALUES ('theme', 'dark') ON DUPLICATE KEY UPDATE setting_value = 'light';"
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|REPLACE INTO settings (setting_key, setting_value) VALUES ('theme', 'dark') ON DUPLICATE KEY UPDATE setting_value = 'light';
    ),
  )
}

///|
test "MySQL basic LOAD DATA statement" {
  let tokens = "LOAD DATA INFILE '/tmp/data.csv' INTO TABLE users;"
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|LOAD DATA INFILE '/tmp/data.csv' INTO TABLE users;
    ),
  )
}

///|
test "MySQL LOAD DATA with LOCAL and REPLACE" {
  let tokens = "LOAD DATA LOCAL INFILE '/tmp/users.txt' REPLACE INTO TABLE employees;"
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|LOAD DATA LOCAL INFILE '/tmp/users.txt' REPLACE INTO TABLE employees;
    ),
  )
}

///|
test "MySQL LOAD DATA with FIELDS options" {
  let tokens = "LOAD DATA INFILE '/data/products.csv' INTO TABLE products CHARACTER SET utf8 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"';"
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|LOAD DATA INFILE '/data/products.csv' INTO TABLE products CHARACTER SET utf8 FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"';
    ),
  )
}

///|
test "MySQL LOAD DATA with LINES options" {
  let tokens = "LOAD DATA INFILE '/tmp/logs.txt' INTO TABLE logs LINES STARTING BY '>>>' TERMINATED BY '\n' IGNORE 5 LINES;"
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|LOAD DATA INFILE '/tmp/logs.txt' INTO TABLE logs LINES STARTING BY '>>>' TERMINATED BY '
      #|' IGNORE 5 LINES;
    ),
  )
}

///|
test "MySQL LOAD DATA with column list and SET" {
  let tokens = "LOAD DATA INFILE '/data/sales.csv' IGNORE INTO TABLE sales FIELDS TERMINATED BY ',' (date, amount, customer) SET created_at = NOW();"
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|LOAD DATA INFILE '/data/sales.csv' IGNORE INTO TABLE sales FIELDS TERMINATED BY ',' (date, amount, customer) SET created_at = NOW();
    ),
  )
}
