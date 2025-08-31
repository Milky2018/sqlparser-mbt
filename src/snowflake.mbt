///|
/// Snowflake dialect - supports Snowflake specific syntax
pub struct Snowflake {}

///|
impl Dialect for Snowflake with supports_string_literal_backslash_escape(_self) {
  true
}

///|
impl Dialect for Snowflake with supports_boolean_literals(_self) {
  true
}

///|
impl Dialect for Snowflake with supports_filter_during_aggregation(_self) {
  false
}

///|
impl Dialect for Snowflake with supports_within_after_array_aggregation(_self) {
  false
}

///|
impl Dialect for Snowflake with requires_column_types_in_create_table(_self) {
  true
}

///|
impl Dialect for Snowflake with supports_if_not_exists(_self) {
  true
}

///|
impl Dialect for Snowflake with supports_double_quoted_identifiers(_self) {
  true
}

///|
impl Dialect for Snowflake with parse_statement(
  _self : Snowflake,
  _parser : Parser,
  _tokens : ArrayView[Token],
) -> ParserResult[Statement]? raise ParserError {
  None
}

///|
impl Dialect for Snowflake with parse_expr(
  _self : Snowflake,
  _tokens : ArrayView[Token],
) -> ParserResult[Expr]? raise ParserError {
  None
}