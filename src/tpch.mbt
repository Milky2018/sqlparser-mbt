///|
fn read_and_parse(path : String) -> Statement {
  let input = @fs.read_file_to_string(path) catch {
    e => {
      println("Read file error: \{e.to_string()}")
      panic()
    }
  }
  parse_sql(input) catch {
    LexerError(e) => {
      println(e)
      panic()
    }
    ParserError(e) => {
      println(e)
      panic()
    }
  }
}

///|
test "TPCH 1" {
  let stmt = read_and_parse("src/tpch/1.sql")
  inspect(
    stmt,
    content="SELECT l_returnflag, l_linestatus, sum(l_quantity) AS sum_qty, sum(l_extendedprice) AS sum_base_price, sum((l_extendedprice * (1 - l_discount))) AS sum_disc_price, sum(((l_extendedprice * (1 - l_discount)) * (1 + l_tax))) AS sum_charge, avg(l_quantity) AS avg_qty, avg(l_extendedprice) AS avg_price, avg(l_discount) AS avg_disc, count(*) AS count_order FROM lineitem WHERE (l_shipdate <= (DATE '1998-12-01' - INTERVAL '90' DAY (3))) GROUP BY l_returnflag, l_linestatus ORDER BY l_returnflag, l_linestatus;",
  )
}

///|
test "TPCH 2" {
  let stmt = read_and_parse("src/tpch/2.sql")
  inspect(stmt, content="SELECT s_acctbal, s_name, n_name, p_partkey, p_mfgr, s_address, s_phone, s_comment FROM part;")
}
