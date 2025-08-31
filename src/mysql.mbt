///|
pub struct MySQL {}

///|
impl Dialect for MySQL with supports_string_literal_backslash_escape(_self) {
  true
}

///|
impl Dialect for MySQL with supports_boolean_literals(_self) {
  true
}

///|
impl Dialect for MySQL with supports_filter_during_aggregation(_self) {
  false
}

///|
impl Dialect for MySQL with supports_double_quoted_identifiers(_self) {
  false
}

///|
impl Dialect for MySQL with supports_if_not_exists(_self) {
  true
}

///|
impl Dialect for MySQL with parse_statement(
  _self : MySQL,
  _parser : Parser,
  _tokens : ArrayView[Token],
) -> ParserResult[Statement]? raise ParserError {
  // Following datafusion-sqlparser-rs pattern - return None for now
  // SHOW statements should be handled in the main parser
  None
}

///|
impl Dialect for MySQL with parse_expr(
  _self : MySQL,
  _tokens : ArrayView[Token],
) -> ParserResult[Expr]? raise ParserError {
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
