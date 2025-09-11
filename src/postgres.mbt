///|
pub(all) struct Postgres {}

///|
pub impl Dialect for Postgres with supports_string_literal_backslash_escape(
  _self,
) {
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
pub impl Dialect for Postgres with supports_within_after_array_aggregation(
  _self,
) {
  true
}

///|
pub impl Dialect for Postgres with supports_double_quoted_identifiers(_self) {
  true
}

///|
pub impl Dialect for Postgres with supports_array_syntax(_self) {
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
    [Keyword(Listen), Identifier(channel), Semicolon, .. rest] =>
      // PostgreSQL LISTEN statement
      Some((Statement::Listen(channel), rest))
    [Keyword(Notify), Identifier(channel), Semicolon, .. rest] =>
      // PostgreSQL NOTIFY statement without payload
      Some((Statement::Notify(channel, None), rest))
    [
      Keyword(Notify),
      Identifier(channel),
      Comma,
      StringLiteral(payload),
      Semicolon,
      .. rest,
    ] =>
      // PostgreSQL NOTIFY statement with payload
      Some((Statement::Notify(channel, Some(payload)), rest))
    _ => None // Fall back to generic parsing
  }
}

///|
pub impl Dialect for Postgres with parse_expr(
  _self : Postgres,
  tokens : ArrayView[Token],
) -> ParserResult[Expr]? raise ParserError {
  match tokens {
    [Keyword(Array), LBracket, .. _tokens] =>
      // PostgreSQL ARRAY[...] syntax - delegate to parser
      None // Let the main parser handle this
    [LBracket, .. _tokens] =>
      // PostgreSQL bracket array syntax [1, 2, 3] - delegate to parser  
      None // Let the main parser handle this
    _ => None
  }
}

///|
test "PostgreSQL LISTEN" {
  let tokens = "LISTEN my_channel;"
  let stmt = parse_sql(dialect=Postgres::{  }, tokens).stmts[0] |> pretty_print
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
  let stmt = parse_sql(dialect=Postgres::{  }, tokens).stmts[0] |> pretty_print
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
  let stmt = parse_sql(dialect=Postgres::{  }, tokens).stmts[0] |> pretty_print
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
  let stmt = parse_sql(dialect=Postgres::{  }, tokens).stmts[0] |> pretty_print
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
  let stmt = parse_sql(dialect=Postgres::{  }, tokens).stmts[0] |> pretty_print
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
  let stmt = parse_sql(dialect=Postgres::{  }, tokens).stmts[0] |> pretty_print
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
  let stmt = parse_sql(dialect=Postgres::{  }, tokens).stmts[0] |> pretty_print
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
  let stmt = parse_sql(dialect=Postgres::{  }, tokens).stmts[0] |> pretty_print
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
  let stmt = parse_sql(dialect=Postgres::{  }, tokens).stmts[0] |> pretty_print
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

///|
// Negative tests: PostgreSQL-specific syntax should fail with other dialects

test "ARRAY syntax fails with MySQL dialect" {
  let tokens = "SELECT ARRAY[1, 2, 3] FROM test;"
  try {
    let _ = parse_sql(dialect=MySQL::{  }, tokens)
    abort("Expected parsing to fail with MySQL dialect")
  } catch {
    _e => () // Expected behavior - parsing should fail
  }
}

///|
test "Bracket array syntax fails with MySQL dialect" {
  let tokens = "SELECT [1, 2, 3] FROM test;"
  try {
    let _ = parse_sql(dialect=MySQL::{  }, tokens)
    abort("Expected parsing to fail with MySQL dialect")
  } catch {
    _e => () // Expected behavior - parsing should fail
  }
}

///|
test "ARRAY syntax fails with SQLite dialect" {
  let tokens = "SELECT ARRAY[1, 2, 3] FROM test;"
  try {
    let _ = parse_sql(dialect=SQLite::{  }, tokens)
    abort("Expected parsing to fail with SQLite dialect")
  } catch {
    _e => () // Expected behavior - parsing should fail
  }
}

///|
test "Bracket array syntax fails with SQLite dialect" {
  let tokens = "SELECT [1, 2, 3] FROM test;"
  try {
    let _ = parse_sql(dialect=SQLite::{  }, tokens)
    abort("Expected parsing to fail with SQLite dialect")
  } catch {
    _e => () // Expected behavior - parsing should fail
  }
}

///|
test "LISTEN statement fails with MySQL dialect" {
  let tokens = "LISTEN my_channel;"
  try {
    let _ = parse_sql(dialect=MySQL::{  }, tokens)
    abort("Expected parsing to fail with MySQL dialect")
  } catch {
    _e => () // Expected behavior - parsing should fail
  }
}

///|
test "NOTIFY statement fails with MySQL dialect" {
  let tokens = "NOTIFY my_channel;"
  try {
    let _ = parse_sql(dialect=MySQL::{  }, tokens)
    abort("Expected parsing to fail with MySQL dialect")
  } catch {
    _e => () // Expected behavior - parsing should fail
  }
}

///|
test "Complex PostgreSQL arrays fail with generic dialect" {
  let tokens = "SELECT ARRAY[ARRAY[1, 2], [3, 4]] FROM test;"
  try {
    let _ = parse_sql(dialect=Generic::{  }, tokens)
    abort("Expected parsing to fail with Generic dialect")
  } catch {
    _e => () // Expected behavior - parsing should fail
  }
}

///|
// PostgreSQL JSON operator tests

test "PostgreSQL JSON extract operator" {
  let tokens = "SELECT data -> 'key' FROM json_table;"
  let stmt = parse_sql(dialect=Postgres::{  }, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  data -> 'key'
      #|FROM
      #|  json_table;
    ),
  )
}

///|
test "PostgreSQL JSON extract text operator" {
  let tokens = "SELECT data ->> 'key' FROM json_table;"
  let stmt = parse_sql(dialect=Postgres::{  }, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  data ->> 'key'
      #|FROM
      #|  json_table;
    ),
  )
}

///|
test "PostgreSQL JSON path extract operator" {
  let tokens = "SELECT data #> ARRAY['key', 'subkey'] FROM json_table;"
  let stmt = parse_sql(dialect=Postgres::{  }, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  data #> ARRAY['key', 'subkey']
      #|FROM
      #|  json_table;
    ),
  )
}

///|
test "PostgreSQL JSON contains operator" {
  let tokens = "SELECT data @> '{\"key\":\"value\"}' FROM json_table;"
  let stmt = parse_sql(dialect=Postgres::{  }, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  data @> '{"key":"value"}'
      #|FROM
      #|  json_table;
    ),
  )
}

///|
test "PostgreSQL JSON contained in operator" {
  let tokens = "SELECT '{\"a\":1}' <@ data FROM json_table;"
  let stmt = parse_sql(dialect=Postgres::{  }, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  '{"a":1}' <@ data
      #|FROM
      #|  json_table;
    ),
  )
}

///|
// PostgreSQL FILTER aggregation tests

test "PostgreSQL COUNT with FILTER" {
  let tokens = "SELECT count(*) FILTER (WHERE active) FROM users;"
  let stmt = parse_sql(dialect=Postgres::{  }, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  count(*) FILTER (WHERE active)
      #|FROM
      #|  users;
    ),
  )
}

///|
test "PostgreSQL COUNT without FILTER" {
  let tokens = "SELECT count(*) FROM users;"
  let stmt = parse_sql(dialect=Postgres::{  }, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  count(*)
      #|FROM
      #|  users;
    ),
  )
}

///|
test "PostgreSQL SUM with FILTER" {
  let tokens = "SELECT sum(amount) FILTER (WHERE status = 'completed') FROM orders;"
  let stmt = parse_sql(dialect=Postgres::{  }, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  sum(amount) FILTER (WHERE status = 'completed')
      #|FROM
      #|  orders;
    ),
  )
}

///|
test "PostgreSQL multiple aggregations with FILTER" {
  let tokens = "SELECT count(*) FILTER (WHERE active), avg(age) FILTER (WHERE age > 18) FROM users;"
  let stmt = parse_sql(dialect=Postgres::{  }, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  count(*) FILTER (WHERE active),
      #|  avg(age) FILTER (WHERE age > 18)
      #|FROM
      #|  users;
    ),
  )
}
