///|
pub struct MySQL {}

///|
impl Dialect for MySQL with supports_string_literal_backslash_escape(_self) {
  true
}

///|
impl Dialect for MySQL with supports_boolean_literals(_self) {
  false
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
