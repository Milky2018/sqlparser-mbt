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