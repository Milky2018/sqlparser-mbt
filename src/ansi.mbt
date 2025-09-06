///|
/// ANSI SQL dialect - adheres to ANSI SQL standards
pub(all) struct ANSI {}

///|
pub impl Dialect for ANSI with supports_string_literal_backslash_escape(_self) {
  false
}

///|
pub impl Dialect for ANSI with supports_boolean_literals(_self) {
  true
}

///|
pub impl Dialect for ANSI with supports_filter_during_aggregation(_self) {
  false
}

///|
pub impl Dialect for ANSI with supports_within_after_array_aggregation(_self) {
  false
}

///|
pub impl Dialect for ANSI with requires_column_types_in_create_table(_self) {
  true
}

///|
pub impl Dialect for ANSI with supports_if_not_exists(_self) {
  false
}

///|
pub impl Dialect for ANSI with supports_double_quoted_identifiers(_self) {
  true
}

///|
pub impl Dialect for ANSI with parse_statement(
  _self : ANSI,
  _parser : Parser,
  _tokens : ArrayView[Token],
) -> ParserResult[Statement]? raise ParserError {
  None
}

///|
pub impl Dialect for ANSI with parse_expr(
  _self : ANSI,
  _tokens : ArrayView[Token],
) -> ParserResult[Expr]? raise ParserError {
  None
}
