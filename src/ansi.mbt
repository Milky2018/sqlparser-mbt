///|
/// ANSI SQL dialect - adheres to ANSI SQL standards
pub struct ANSI {}

///|
impl Dialect for ANSI with supports_string_literal_backslash_escape(_self) {
  false
}

///|
impl Dialect for ANSI with supports_boolean_literals(_self) {
  true
}

///|
impl Dialect for ANSI with supports_filter_during_aggregation(_self) {
  false
}

///|
impl Dialect for ANSI with supports_within_after_array_aggregation(_self) {
  false
}

///|
impl Dialect for ANSI with requires_column_types_in_create_table(_self) {
  true
}

///|
impl Dialect for ANSI with supports_if_not_exists(_self) {
  false
}

///|
impl Dialect for ANSI with supports_double_quoted_identifiers(_self) {
  true
}