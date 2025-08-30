///|
/// DuckDB dialect - supports DuckDB specific syntax
pub struct DuckDB {}

///|
impl Dialect for DuckDB with supports_string_literal_backslash_escape(_self) {
  false
}

///|
impl Dialect for DuckDB with supports_boolean_literals(_self) {
  true
}

///|
impl Dialect for DuckDB with supports_filter_during_aggregation(_self) {
  true
}

///|
impl Dialect for DuckDB with supports_within_after_array_aggregation(_self) {
  true
}

///|
impl Dialect for DuckDB with requires_column_types_in_create_table(_self) {
  false
}

///|
impl Dialect for DuckDB with supports_if_not_exists(_self) {
  true
}

///|
impl Dialect for DuckDB with supports_double_quoted_identifiers(_self) {
  true
}