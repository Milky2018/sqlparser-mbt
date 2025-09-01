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
pub impl Dialect for MySQL with parse_statement(
  _self : MySQL,
  _parser : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[Statement]? raise ParserError {
  match tokens {
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
