///|
pub(all) struct Postgres {}

///|
pub impl Dialect for Postgres with supports_string_literal_backslash_escape(_self) {
  false
}

///|
pub impl Dialect for Postgres with supports_boolean_literals(_self) {
  true
}

///|
pub impl Dialect for Postgres with supports_filter_during_aggregation(_self) {
  true
}

///|
pub impl Dialect for Postgres with supports_within_after_array_aggregation(_self) {
  true
}

///|
pub impl Dialect for Postgres with supports_double_quoted_identifiers(_self) {
  true
}

///|
pub impl Dialect for Postgres with supports_if_not_exists(_self) {
  true
}

///|
pub impl Dialect for Postgres with requires_column_types_in_create_table(_self) {
  true
}

///|
pub impl Dialect for Postgres with parse_statement(
  _self : Postgres,
  _parser : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[Statement]? raise ParserError {
  match tokens {
    [Keyword(Listen), Identifier(channel), Semicolon, .. rest] => {
      // PostgreSQL LISTEN statement
      Some((Statement::Listen(channel), rest))
    }
    [Keyword(Notify), Identifier(channel), Semicolon, .. rest] => {
      // PostgreSQL NOTIFY statement without payload
      Some((Statement::Notify(channel, None), rest))
    }
    [Keyword(Notify), Identifier(channel), Comma, StringLiteral(payload), Semicolon, .. rest] => {
      // PostgreSQL NOTIFY statement with payload
      Some((Statement::Notify(channel, Some(payload)), rest))
    }
    _ => None  // Fall back to generic parsing
  }
}

///|
pub impl Dialect for Postgres with parse_expr(
  _self : Postgres,
  _tokens : ArrayView[Token],
) -> ParserResult[Expr]? raise ParserError {
  // TODO: Implement PostgreSQL-specific expression parsing (e.g., filter aggregations)
  None
}

///|
test "PostgreSQL LISTEN" {
  let tokens = "LISTEN my_channel;"
  let stmt = parse_sql(dialect=Postgres::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|LISTEN my_channel;
    ),
  )
}

///|
test "PostgreSQL NOTIFY without payload" {
  let tokens = "NOTIFY my_channel;"
  let stmt = parse_sql(dialect=Postgres::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|NOTIFY my_channel;
    ),
  )
}

///|
test "PostgreSQL NOTIFY with payload" {
  let tokens = "NOTIFY my_channel, 'hello world';"
  let stmt = parse_sql(dialect=Postgres::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|NOTIFY my_channel, 'hello world';
    ),
  )
}

///|
// PostgreSQL array syntax tests

test "PostgreSQL ARRAY syntax with integers" {
  let tokens = "SELECT ARRAY[1, 2, 3, 4] FROM test;"
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  ARRAY[1, 2, 3, 4]
      #|FROM
      #|  test;
    ),
  )
}

///|
test "PostgreSQL bracket array syntax" {
  let tokens = "SELECT [1, 2, 3] FROM test;"
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  [1, 2, 3]
      #|FROM
      #|  test;
    ),
  )
}

///|
test "PostgreSQL empty ARRAY" {
  let tokens = "SELECT ARRAY[] FROM test;"
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  ARRAY[]
      #|FROM
      #|  test;
    ),
  )
}

///|
test "PostgreSQL ARRAY with strings" {
  let tokens = "SELECT ARRAY['hello', 'world'] FROM test;"
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  ARRAY['hello', 'world']
      #|FROM
      #|  test;
    ),
  )
}

///|
test "PostgreSQL nested arrays" {
  let tokens = "SELECT ARRAY[ARRAY[1, 2], ARRAY[3, 4]] FROM test;"
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  ARRAY[ARRAY[1, 2], ARRAY[3, 4]]
      #|FROM
      #|  test;
    ),
  )
}

///|
test "PostgreSQL mixed bracket and ARRAY syntax" {
  let tokens = "SELECT ARRAY[[1, 2], [3, 4]] FROM test;"
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  ARRAY[[1, 2], [3, 4]]
      #|FROM
      #|  test;
    ),
  )
}
