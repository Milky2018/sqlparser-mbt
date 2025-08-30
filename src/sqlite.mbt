///|
pub struct SQLite {}

///|
impl Dialect for SQLite with supports_string_literal_backslash_escape(_self) {
  false
}

///|
impl Dialect for SQLite with supports_boolean_literals(_self) {
  true
}

///|
impl Dialect for SQLite with supports_filter_during_aggregation(_self) {
  false
}

///|
impl Dialect for SQLite with requires_column_types_in_create_table(_self) {
  false
}

///|
impl Dialect for SQLite with supports_if_not_exists(_self) {
  true
}

///|
impl Dialect for SQLite with supports_double_quoted_identifiers(_self) {
  true
}