pub struct MySQL {}

impl Dialect for MySQL with supports_string_literal_backslash_escape(_self) {
  true
}

impl Dialect for MySQL with supports_boolean_literals(_self) {
  false
}