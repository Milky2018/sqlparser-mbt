///|
pub struct Postgres {}

///|
impl Dialect for Postgres with supports_string_literal_backslash_escape(_self) {
  false
}

///|
impl Dialect for Postgres with supports_boolean_literals(_self) {
  true
}

///|
impl Dialect for Postgres with supports_filter_during_aggregation(_self) {
  true
}

///|
impl Dialect for Postgres with supports_within_after_array_aggregation(_self) {
  true
}

///|
impl Dialect for Postgres with supports_double_quoted_identifiers(_self) {
  true
}

///|
impl Dialect for Postgres with supports_if_not_exists(_self) {
  true
}
