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
    content=
      #|SELECT
      #|  l_returnflag,
      #|  l_linestatus,
      #|  sum(l_quantity) AS sum_qty,
      #|  sum(l_extendedprice) AS sum_base_price,
      #|  sum(l_extendedprice * 1 - l_discount) AS sum_disc_price,
      #|  sum(l_extendedprice * 1 - l_discount * 1 + l_tax) AS sum_charge,
      #|  avg(l_quantity) AS avg_qty,
      #|  avg(l_extendedprice) AS avg_price,
      #|  avg(l_discount) AS avg_disc,
      #|  count(*) AS count_order
      #|FROM
      #|  lineitem
      #|WHERE
      #|  l_shipdate <= DATE '1998-12-01' - INTERVAL '90' DAY (3)
      #|GROUP BY
      #|  l_returnflag,
      #|  l_linestatus
      #|ORDER BY
      #|  l_returnflag,
      #|  l_linestatus;
    ,
  )
}

///|
test "TPCH 2" {
  let stmt = read_and_parse("src/tpch/2.sql")
  inspect(
    stmt,
    content=
      #|SELECT
      #|  s_acctbal,
      #|  s_name,
      #|  n_name,
      #|  p_partkey,
      #|  p_mfgr,
      #|  s_address,
      #|  s_phone,
      #|  s_comment
      #|FROM
      #|  part,
      #|  supplier,
      #|  partsupp,
      #|  nation,
      #|  region
      #|WHERE
      #|  p_partkey = ps_partkey 
      #|  AND s_suppkey = ps_suppkey 
      #|  AND p_size = 15 
      #|  AND p_type LIKE '%BRASS' 
      #|  AND s_nationkey = n_nationkey 
      #|  AND n_regionkey = r_regionkey 
      #|  AND r_name = 'EUROPE' 
      #|  AND ps_supplycost = (
      #|    SELECT
      #|      min(ps_supplycost)
      #|    FROM
      #|      partsupp,
      #|      supplier,
      #|      nation,
      #|      region
      #|    WHERE
      #|      p_partkey = ps_partkey 
      #|      AND s_suppkey = ps_suppkey 
      #|      AND s_nationkey = n_nationkey 
      #|      AND n_regionkey = r_regionkey 
      #|      AND r_name = 'EUROPE'
      #|    )
      #|ORDER BY
      #|  s_acctbal DESC,
      #|  n_name,
      #|  s_name,
      #|  p_partkey;
    ,
  )
}

///|
test "TPCH 3" {
  let stmt = read_and_parse("src/tpch/3.sql")
  inspect(
    stmt,
    content=
      #|SELECT
      #|  l_orderkey,
      #|  sum(l_extendedprice * 1 - l_discount) AS revenue,
      #|  o_orderdate,
      #|  o_shippriority
      #|FROM
      #|  customer,
      #|  orders,
      #|  lineitem
      #|WHERE
      #|  c_mktsegment = 'BUILDING' 
      #|  AND c_custkey = o_custkey 
      #|  AND l_orderkey = o_orderkey 
      #|  AND o_orderdate < DATE '1995-03-15' 
      #|  AND l_shipdate > DATE '1995-03-15'
      #|GROUP BY
      #|  l_orderkey,
      #|  o_orderdate,
      #|  o_shippriority
      #|ORDER BY
      #|  revenue DESC,
      #|  o_orderdate;
    ,
  )
}

///|
test "TPCH 4" {
  let stmt = read_and_parse("src/tpch/4.sql")
  inspect(
    stmt,
    content=
      #|SELECT
      #|  o_orderpriority,
      #|  count(*) AS order_count
      #|FROM
      #|  orders
      #|WHERE
      #|  o_orderdate >= DATE '1993-07-01' 
      #|  AND o_orderdate < DATE '1993-07-01' + INTERVAL '3' MONTH 
      #|  AND EXISTS (
      #|  SELECT
      #|      *
      #|    FROM
      #|      lineitem
      #|    WHERE
      #|      l_orderkey = o_orderkey 
      #|      AND l_commitdate < l_receiptdate
      #|  )
      #|GROUP BY
      #|  o_orderpriority
      #|ORDER BY
      #|  o_orderpriority;
    ,
  )
}

///|
test "TPCH 5" {
  let stmt = read_and_parse("src/tpch/5.sql")
  inspect(
    stmt,
    content=
      #|SELECT
      #|  n_name,
      #|  sum(l_extendedprice * 1 - l_discount) AS revenue
      #|FROM
      #|  customer,
      #|  orders,
      #|  lineitem,
      #|  supplier,
      #|  nation,
      #|  region
      #|WHERE
      #|  c_custkey = o_custkey 
      #|  AND l_orderkey = o_orderkey 
      #|  AND l_suppkey = s_suppkey 
      #|  AND c_nationkey = s_nationkey 
      #|  AND s_nationkey = n_nationkey 
      #|  AND n_regionkey = r_regionkey 
      #|  AND r_name = 'ASIA' 
      #|  AND o_orderdate >= DATE '1994-01-01' 
      #|  AND o_orderdate < DATE '1994-01-01' + INTERVAL '1' YEAR
      #|GROUP BY
      #|  n_name
      #|ORDER BY
      #|  revenue DESC;
    ,
  )
}

///|
test "TPCH 6" {
  let stmt = read_and_parse("src/tpch/6.sql")
  inspect(
    stmt,
    content=
      #|SELECT
      #|  sum(l_extendedprice * l_discount) AS revenue
      #|FROM
      #|  lineitem
      #|WHERE
      #|  l_shipdate >= DATE '1994-01-01' 
      #|  AND l_shipdate < DATE '1994-01-01' + INTERVAL '1' YEAR 
      #|  AND l_discount BETWEEN 0.06 - 0.01 AND 0.06 + 0.01 
      #|  AND l_quantity < 24;
    ,
  )
}
