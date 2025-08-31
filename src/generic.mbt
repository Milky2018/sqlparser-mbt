///|
/// Generic SQL dialect that supports the union of all other dialects
/// This is the most permissive dialect, useful for parsing various SQL statements
/// from different sources without strict dialect requirements
pub(all) struct Generic {}

///|
pub impl Dialect for Generic with supports_string_literal_backslash_escape(_self) {
  true
}

///|
pub impl Dialect for Generic with supports_boolean_literals(_self) {
  true
}

///|
pub impl Dialect for Generic with supports_filter_during_aggregation(_self) {
  true
}

///|
pub impl Dialect for Generic with supports_within_after_array_aggregation(_self) {
  true
}

///|
pub impl Dialect for Generic with requires_column_types_in_create_table(_self) {
  false
}

///|
pub impl Dialect for Generic with supports_if_not_exists(_self) {
  true
}

///|
pub impl Dialect for Generic with supports_double_quoted_identifiers(_self) {
  true
}

///|
pub impl Dialect for Generic with parse_statement(
  _self : Generic,
  _parser : Parser,
  _tokens : ArrayView[Token],
) -> ParserResult[Statement]? raise ParserError {
  None
}

///|
pub impl Dialect for Generic with parse_expr(
  _self : Generic,
  _tokens : ArrayView[Token],
) -> ParserResult[Expr]? raise ParserError {
  None
}