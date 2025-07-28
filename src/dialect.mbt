///|
pub trait Dialect {
  supports_string_literal_backslash_escape(Self) -> Bool = _
  supports_boolean_literals(Self) -> Bool = _
  parse_expr(Self, tokens : ArrayView[Token]) -> ParserResult[Expr]? raise ParserError = _
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
impl Dialect with parse_expr(_self : Self, _tokens : ArrayView[Token]) -> ParserResult[
  Expr,
]? raise ParserError {
  None
}
