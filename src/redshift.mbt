///|
/// Redshift dialect - supports Amazon Redshift specific syntax
pub struct Redshift {}

///|
impl Dialect for Redshift with supports_string_literal_backslash_escape(_self) {
  true
}

///|
impl Dialect for Redshift with supports_boolean_literals(_self) {
  true
}

///|
impl Dialect for Redshift with supports_filter_during_aggregation(_self) {
  false
}

///|
impl Dialect for Redshift with supports_within_after_array_aggregation(_self) {
  false
}

///|
impl Dialect for Redshift with requires_column_types_in_create_table(_self) {
  true
}

///|
impl Dialect for Redshift with supports_if_not_exists(_self) {
  true
}

///|
impl Dialect for Redshift with supports_double_quoted_identifiers(_self) {
  true
}