///|
pub struct SQLite {}

///|
impl Dialect for SQLite with supports_string_literal_backslash_escape(_self) {
  false
}

///|
impl Dialect for SQLite with supports_boolean_literals(_self) {
  true
}

///|
impl Dialect for SQLite with supports_filter_during_aggregation(_self) {
  false
}

///|
impl Dialect for SQLite with requires_column_types_in_create_table(_self) {
  false
}

///|
impl Dialect for SQLite with supports_if_not_exists(_self) {
  true
}

///|
impl Dialect for SQLite with supports_double_quoted_identifiers(_self) {
  true
}

///|
impl Dialect for SQLite with supports_within_after_array_aggregation(_self) {
  false
}

///|
impl Dialect for SQLite with parse_statement(
  _self : SQLite,
  _parser : Parser,
  _tokens : ArrayView[Token],
) -> ParserResult[Statement]? raise ParserError {
  None
}

///|
impl Dialect for SQLite with parse_expr(
  _self : SQLite,
  _tokens : ArrayView[Token],
) -> ParserResult[Expr]? raise ParserError {
  None
}