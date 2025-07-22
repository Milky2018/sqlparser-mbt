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
