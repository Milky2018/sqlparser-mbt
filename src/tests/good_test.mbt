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

///|
test {
  "SELECT * FROM t1 UNION SELECT * FROM t2 ORDER BY col1;" |> pass
}

///|
test {
  "SELECT * FROM (SELECT * FROM t1);" |> pass
}

///|
test {
  "SELECT * FROM t1 UNION (SELECT * FROM t2 UNION SELECT * FROM t3) ORDER BY col1;"
  |> pass
}

///|
test {
  "SELECT TOP 10 * FROM t1 ORDER BY col1, col2;" |> pass
}

///|
test {
  "SELECT a, MAX(b), MAX(c, d), CUSTOM(q, UP(r)) AS f FROM t1;" |> pass
}

///|
test {
  "SELECT * FROM t WHERE a BETWEEN 1 and c;" |> pass
}

///|
test {
  "SELECT * FROM t WHERE a = ? AND b = ?;" |> pass
}

///|
test {
  "SELECT City.name, Product.category, SUM(price) FROM fact INNER JOIN City ON fact.city_id = City.id INNER JOIN Product ON fact.product_id = Product.id GROUP BY City.name, Product.category;"
  |> pass
}

///|
test {
  "SELECT SUBSTR(a, 3, 5) FROM t;" |> pass
}

///|
test {
  "SELECT * FROM t WHERE a = DATE '1996-12-31';" |> pass
}

///|
test {
  (
    #| SELECT t1.a, t1.b, t2.c FROM "table" AS t1 JOIN (SELECT * FROM foo JOIN bar ON foo.id = bar.id) t2 ON t1.a = t2.b WHERE (t1.b OR NOT t1.a) AND t2.c = 12.5
  )
  |> pass
}

///|
test {
  "SELECT * FROM t1 JOIN t2 ON c1 = c2;" |> pass
}

///|
test {
  "SELECT a, SUM(b) FROM t2 GROUP BY a HAVING SUM(b) > 100;" |> pass
}

///|
test {
  "INSERT INTO test_table VALUES (1, 2, 'test');" |> pass
}

///|
test {
  "INSERT INTO test_table (id, value, name) VALUES (1, 2, 'test');" |> pass
}

///|
test {
  "INSERT INTO test_table SELECT * FROM students;" |> pass
}

///|
test {
  "INSERT INTO some_schema.test_table SELECT * FROM another_schema.students;" |> pass
}

///|
test {
  "CREATE TABLE IF NOT EXISTS \"table\" (id INTEGER);" |> pass
}

///|
test {
  "CREATE TABLE students_2 AS SELECT * FROM students;" |> pass
}

///|
test {
  "CREATE TABLE students_3 AS SELECT city, grade FROM students WHERE grade > 3.0;" |> pass
}

///|
test {
  "DELETE FROM students WHERE grade > 3.0" |> pass
}

///|
test {
  "DELETE FROM students" |> pass
}

///|
test {
  "UPDATE students SET grade = 1.3 WHERE name = 'Max Mustermann';" |> pass
}

///|
test {
  "UPDATE students SET grade = 1.3, name='Felix Fürstenberg' WHERE name = 'Max Mustermann';" |> pass
}

///|
test {
  "UPDATE students SET grade = 1.0;" |> pass
}

///|
test {
  "UPDATE some_schema.students SET grade = 1.0;" |> pass
}

///|
test {
  "TRUNCATE students" |> pass
}

///|
test {
  "DROP TABLE students;" |> pass
}

///|
test {
  "DROP TABLE IF EXISTS students;" |> pass
}

///|
test {
  "ALTER TABLE mytable DROP COLUMN IF EXISTS mycolumn;" |> pass
}

///|
test {
  "ALTER TABLE IF EXISTS mytable DROP COLUMN IF EXISTS mycolumn;" |> pass
}
