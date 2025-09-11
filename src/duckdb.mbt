///|
/// DuckDB dialect - supports DuckDB specific syntax
pub(all) struct DuckDB {}

///|
pub impl Dialect for DuckDB with supports_string_literal_backslash_escape(_self) {
  false
}

///|
pub impl Dialect for DuckDB with supports_boolean_literals(_self) {
  true
}

///|
pub impl Dialect for DuckDB with supports_filter_during_aggregation(_self) {
  true
}

///|
pub impl Dialect for DuckDB with supports_within_after_array_aggregation(_self) {
  true
}

///|
pub impl Dialect for DuckDB with requires_column_types_in_create_table(_self) {
  false
}

///|
pub impl Dialect for DuckDB with supports_if_not_exists(_self) {
  true
}

///|
pub impl Dialect for DuckDB with supports_double_quoted_identifiers(_self) {
  true
}

///|
pub impl Dialect for DuckDB with parse_statement(
  _self : DuckDB,
  _parser : Parser,
  _tokens : ArrayView[Token],
) -> ParserResult[Statement]? raise ParserError {
  None
}

///|
pub impl Dialect for DuckDB with parse_expr(
  _self : DuckDB,
  _tokens : ArrayView[Token],
) -> ParserResult[Expr]? raise ParserError {
  None
}
