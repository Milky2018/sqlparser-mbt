// These tests are copied from https://github.com/hyrise/sql-parser/blob/main/test/queries/queries-good.sql

///|
fn pass(input : String) -> Unit {
  (@sqlparser.parse_sql(input) catch {
    e => {
      println(e)
      panic()
    }
  })
  |> ignore
}

///|
test {
  "SELECT * FROM orders;" |> pass
}

///|
test {
  "SELECT a FROM foo WHERE a > 12 OR b > 3 AND NOT c LIMIT 10;" |> pass
}

///|
test {
  "SELECT a FROM some_schema.foo WHERE a > 12 OR b > 3 AND NOT c LIMIT 10;"
  |> pass
}

///|
test {
  (
    #|SELECT col1 AS myname, col2, 'test' FROM "table", foo AS t WHERE age > 12 AND zipcode = 12345 GROUP BY col1;
  )
  |> pass
}

///|
test {
  (
    #|SELECT * from "table" JOIN table2 ON a = b WHERE (b OR NOT a) AND a = 12.5
  )
  |> pass
}

///|
test {
  "(SELECT a FROM foo WHERE a > 12 OR b > 3 AND c NOT LIKE 's%' LIMIT 10);"
  |> pass
}

///|
test {
  (
    #|SELECT * FROM "table" LIMIT 10 OFFSET 10; SELECT * FROM another;
  )
  |> pass
}

test {
  "SELECT * FROM t1 UNION SELECT * FROM t2 ORDER BY col1;" |> pass
}

test {
  "SELECT * FROM (SELECT * FROM t1);" |> pass
}

test {
  "SELECT * FROM t1 UNION (SELECT * FROM t2 UNION SELECT * FROM t3) ORDER BY col1;" |> pass
}

