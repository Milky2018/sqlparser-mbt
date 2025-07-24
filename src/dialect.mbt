///|
pub trait Dialect {
  supports_string_literal_backslash_escape(Self) -> Bool = _
}

///|
impl Dialect with supports_string_literal_backslash_escape(_self) {
  false
}
