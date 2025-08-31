///|
/// BigQuery dialect - supports Google BigQuery specific syntax
pub struct BigQuery {}

///|
impl Dialect for BigQuery with supports_string_literal_backslash_escape(_self) {
  true
}

///|
impl Dialect for BigQuery with supports_boolean_literals(_self) {
  true
}

///|
impl Dialect for BigQuery with supports_filter_during_aggregation(_self) {
  false
}

///|
impl Dialect for BigQuery with supports_within_after_array_aggregation(_self) {
  false
}

///|
impl Dialect for BigQuery with requires_column_types_in_create_table(_self) {
  true
}

///|
impl Dialect for BigQuery with supports_if_not_exists(_self) {
  true
}

///|
impl Dialect for BigQuery with supports_double_quoted_identifiers(_self) {
  false
}

///|
impl Dialect for BigQuery with parse_statement(
  _self : BigQuery,
  _parser : Parser,
  _tokens : ArrayView[Token],
) -> ParserResult[Statement]? raise ParserError {
  None
}

///|
impl Dialect for BigQuery with parse_expr(
  _self : BigQuery,
  _tokens : ArrayView[Token],
) -> ParserResult[Expr]? raise ParserError {
  None
}