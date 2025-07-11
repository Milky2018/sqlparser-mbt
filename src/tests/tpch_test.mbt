///|
test "TPCH 1" {
  let input = @fs.read_file_to_string("src/tests/tpch/1.sql")
  let stmt = @sqlparser.parse_sql(input) catch {
    LexerError(e) => {
      println(e)
      panic()
    }
    ParserError(e) => {
      println(e)
      panic()
    }
  }
  inspect(stmt, content="SELECT l_returnflag, l_linestatus, sum(l_quantity) AS sum_qty, sum(l_extendedprice) AS sum_base_price, sum((l_extendedprice * (1 - l_discount))) AS sum_disc_price, sum(((l_extendedprice * (1 - l_discount)) * (1 + l_tax))) AS sum_charge, avg(l_quantity) AS avg_qty, avg(l_extendedprice) AS avg_price, avg(l_discount) AS avg_disc, count(*) AS count_order FROM lineitem WHERE (l_shipdate <= date);")
}
