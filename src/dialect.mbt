///|
pub trait Dialect {
  /// Whether this dialect supports using backslash as escape character in string literals
  supports_string_literal_backslash_escape(Self) -> Bool = _
  
  /// Whether this dialect supports boolean literals (TRUE/FALSE)
  supports_boolean_literals(Self) -> Bool = _
  
  /// Whether this dialect supports FILTER during aggregation (PostgreSQL style)
  supports_filter_during_aggregation(Self) -> Bool = _
  
  /// Whether this dialect supports WITHIN after array aggregation functions
  supports_within_after_array_aggregation(Self) -> Bool = _
  
  /// Whether this dialect requires specifying column types in CREATE TABLE
  requires_column_types_in_create_table(Self) -> Bool = _
  
  /// Whether this dialect supports IF NOT EXISTS in CREATE TABLE
  supports_if_not_exists(Self) -> Bool = _
  
  /// Whether this dialect supports double quotes for identifiers  
  supports_double_quoted_identifiers(Self) -> Bool = _
  
  /// Whether this dialect supports array syntax (ARRAY[...] and [...])
  supports_array_syntax(Self) -> Bool = _
  
  /// Custom expression parsing for dialect-specific syntax
  parse_expr(Self, tokens : ArrayView[Token]) -> ParserResult[Expr]? raise ParserError = _
  
  /// Custom statement parsing for dialect-specific syntax
  parse_statement(Self, parser : Parser, tokens : ArrayView[Token]) -> ParserResult[Statement]? raise ParserError = _
}

///|
impl Dialect with supports_string_literal_backslash_escape(_self) {
  false
}

///|
impl Dialect with supports_boolean_literals(_self) {
  true
}

///|
impl Dialect with supports_filter_during_aggregation(_self) {
  false
}

///|
impl Dialect with supports_within_after_array_aggregation(_self) {
  false
}

///|
impl Dialect with requires_column_types_in_create_table(_self) {
  true
}

///|
impl Dialect with supports_if_not_exists(_self) {
  true
}

///|
impl Dialect with supports_double_quoted_identifiers(_self) {
  false
}

///|
impl Dialect with supports_array_syntax(_self) {
  false
}

///|
impl Dialect with parse_expr(_self : Self, _tokens : ArrayView[Token]) -> ParserResult[
  Expr,
]? raise ParserError {
  None
}

///|
impl Dialect with parse_statement(
  _self : Self, 
  _parser : Parser, 
  _tokens : ArrayView[Token]
) -> ParserResult[Statement]? raise ParserError {
  // Debug: If this is being called instead of dialect-specific implementation,
  // we'll know there's a dispatch issue
  None
}
