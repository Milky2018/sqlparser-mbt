///|
fn read_and_parse(path : String) -> @sqlparser.Statements {
  let input = @fs.read_file_to_string(path) catch {
    e => {
      println("Read file error: \{e.to_string()}")
      panic()
    }
  }
  @sqlparser.parse_sql(input) catch {
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
  let stmt = read_and_parse("src/tests/tpch/1.sql") |> @sqlparser.pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  l_returnflag,
      #|  l_linestatus,
      #|  sum(l_quantity) AS sum_qty,
      #|  sum(l_extendedprice) AS sum_base_price,
      #|  sum(l_extendedprice * (1 - l_discount)) AS sum_disc_price,
      #|  sum(l_extendedprice * (1 - l_discount) * (1 + l_tax)) AS sum_charge,
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
    ),
  )
}

///|
test "TPCH 2" {
  let stmt = read_and_parse("src/tests/tpch/2.sql") |> @sqlparser.pretty_print
  inspect(
    stmt,
    content=(
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
      #|  )
      #|ORDER BY
      #|  s_acctbal DESC,
      #|  n_name,
      #|  s_name,
      #|  p_partkey;
    ),
  )
}

///|
test "TPCH 3" {
  let stmt = read_and_parse("src/tests/tpch/3.sql") |> @sqlparser.pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  l_orderkey,
      #|  sum(l_extendedprice * (1 - l_discount)) AS revenue,
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
    ),
  )
}

///|
test "TPCH 4" {
  let stmt = read_and_parse("src/tests/tpch/4.sql") |> @sqlparser.pretty_print
  inspect(
    stmt,
    content=(
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
    ),
  )
}

///|
test "TPCH 5" {
  let stmt = read_and_parse("src/tests/tpch/5.sql") |> @sqlparser.pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  n_name,
      #|  sum(l_extendedprice * (1 - l_discount)) AS revenue
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
    ),
  )
}

///|
test "TPCH 6" {
  let stmt = read_and_parse("src/tests/tpch/6.sql") |> @sqlparser.pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  sum(l_extendedprice * l_discount) AS revenue
      #|FROM
      #|  lineitem
      #|WHERE
      #|  l_shipdate >= DATE '1994-01-01' 
      #|  AND l_shipdate < DATE '1994-01-01' + INTERVAL '1' YEAR 
      #|  AND l_discount BETWEEN 0.06 - 0.01 AND 0.06 + 0.01 
      #|  AND l_quantity < 24;
    ),
  )
}

///|
test "TPCH 7" {
  let stmt = read_and_parse("src/tests/tpch/7.sql") |> @sqlparser.pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  supp_nation,
      #|  cust_nation,
      #|  l_year,
      #|  sum(volume) AS revenue
      #|FROM
      #|  (
      #|    SELECT
      #|      n1.n_name AS supp_nation,
      #|      n2.n_name AS cust_nation,
      #|      EXTRACT(YEAR FROM l_shipdate) AS l_year,
      #|      l_extendedprice * (1 - l_discount) AS volume
      #|    FROM
      #|      supplier,
      #|      lineitem,
      #|      orders,
      #|      customer,
      #|      nation AS n1,
      #|      nation AS n2
      #|    WHERE
      #|      s_suppkey = l_suppkey 
      #|      AND o_orderkey = l_orderkey 
      #|      AND c_custkey = o_custkey 
      #|      AND s_nationkey = n1.n_nationkey 
      #|      AND c_nationkey = n2.n_nationkey 
      #|      AND ((
      #|        n1.n_name = 'FRANCE' 
      #|        AND n2.n_name = 'GERMANY'
      #|      ) 
      #|      OR (
      #|        n1.n_name = 'GERMANY' 
      #|        AND n2.n_name = 'FRANCE'
      #|      )) 
      #|      AND l_shipdate BETWEEN DATE '1995-01-01' AND DATE '1996-12-31'
      #|  ) AS shipping
      #|GROUP BY
      #|  supp_nation,
      #|  cust_nation,
      #|  l_year
      #|ORDER BY
      #|  supp_nation,
      #|  cust_nation,
      #|  l_year;
    ),
  )
}

///|
test "TPCH 8" {
  let stmt = read_and_parse("src/tests/tpch/8.sql") |> @sqlparser.pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  o_year,
      #|  sum(CASE
      #|    WHEN nation = 'BRAZIL' THEN volume
      #|    ELSE 0
      #|  END) / sum(volume) AS mkt_share
      #|FROM
      #|  (
      #|    SELECT
      #|      EXTRACT(YEAR FROM o_orderdate) AS o_year,
      #|      l_extendedprice * (1 - l_discount) AS volume,
      #|      n2.n_name AS nation
      #|    FROM
      #|      part,
      #|      supplier,
      #|      lineitem,
      #|      orders,
      #|      customer,
      #|      nation AS n1,
      #|      nation AS n2,
      #|      region
      #|    WHERE
      #|      p_partkey = l_partkey 
      #|      AND s_suppkey = l_suppkey 
      #|      AND l_orderkey = o_orderkey 
      #|      AND o_custkey = c_custkey 
      #|      AND c_nationkey = n1.n_nationkey 
      #|      AND n1.n_regionkey = r_regionkey 
      #|      AND r_name = 'AMERICA' 
      #|      AND s_nationkey = n2.n_nationkey 
      #|      AND o_orderdate BETWEEN DATE '1995-01-01' AND DATE '1996-12-31' 
      #|      AND p_type = 'ECONOMY ANODIZED STEEL'
      #|  ) AS all_nations
      #|GROUP BY
      #|  o_year
      #|ORDER BY
      #|  o_year;
    ),
  )
}

///|
test "TPCH 9" {
  let stmt = read_and_parse("src/tests/tpch/9.sql") |> @sqlparser.pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  nation,
      #|  o_year,
      #|  sum(amount) AS sum_profit
      #|FROM
      #|  (
      #|    SELECT
      #|      n_name AS nation,
      #|      EXTRACT(YEAR FROM o_orderdate) AS o_year,
      #|      l_extendedprice * (1 - l_discount) - ps_supplycost * l_quantity AS amount
      #|    FROM
      #|      part,
      #|      supplier,
      #|      lineitem,
      #|      partsupp,
      #|      orders,
      #|      nation
      #|    WHERE
      #|      s_suppkey = l_suppkey 
      #|      AND ps_suppkey = l_suppkey 
      #|      AND ps_partkey = l_partkey 
      #|      AND p_partkey = l_partkey 
      #|      AND o_orderkey = l_orderkey 
      #|      AND s_nationkey = n_nationkey 
      #|      AND p_name LIKE '%green%'
      #|  ) AS profit
      #|GROUP BY
      #|  nation,
      #|  o_year
      #|ORDER BY
      #|  nation,
      #|  o_year DESC;
    ),
  )
}

///|
test "TPCH 10" {
  let stmt = read_and_parse("src/tests/tpch/10.sql") |> @sqlparser.pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  c_custkey,
      #|  c_name,
      #|  sum(l_extendedprice * (1 - l_discount)) AS revenue,
      #|  c_acctbal,
      #|  n_name,
      #|  c_address,
      #|  c_phone,
      #|  c_comment
      #|FROM
      #|  customer,
      #|  orders,
      #|  lineitem,
      #|  nation
      #|WHERE
      #|  c_custkey = o_custkey 
      #|  AND l_orderkey = o_orderkey 
      #|  AND o_orderdate >= DATE '1993-10-01' 
      #|  AND o_orderdate < DATE '1993-10-01' + INTERVAL '3' MONTH 
      #|  AND l_returnflag = 'R' 
      #|  AND c_nationkey = n_nationkey
      #|GROUP BY
      #|  c_custkey,
      #|  c_name,
      #|  c_acctbal,
      #|  c_phone,
      #|  n_name,
      #|  c_address,
      #|  c_comment
      #|ORDER BY
      #|  revenue DESC;
    ),
  )
}

///|
test "TPCH 11" {
  let stmt = read_and_parse("src/tests/tpch/11.sql") |> @sqlparser.pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  ps_partkey,
      #|  sum(ps_supplycost * ps_availqty) AS value
      #|FROM
      #|  partsupp,
      #|  supplier,
      #|  nation
      #|WHERE
      #|  ps_suppkey = s_suppkey 
      #|  AND s_nationkey = n_nationkey 
      #|  AND n_name = 'GERMANY'
      #|GROUP BY
      #|  ps_partkey
      #|HAVING
      #|  sum(ps_supplycost * ps_availqty) > (
      #|    SELECT
      #|      sum(ps_supplycost * ps_availqty) * 0.0001
      #|    FROM
      #|      partsupp,
      #|      supplier,
      #|      nation
      #|    WHERE
      #|      ps_suppkey = s_suppkey 
      #|      AND s_nationkey = n_nationkey 
      #|      AND n_name = 'GERMANY'
      #|  )
      #|ORDER BY
      #|  value DESC;
    ),
  )
}

///|
test "TPCH 12" {
  let stmt = read_and_parse("src/tests/tpch/12.sql") |> @sqlparser.pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  l_shipmode,
      #|  sum(CASE
      #|    WHEN o_orderpriority = '1-URGENT' 
      #|    OR o_orderpriority = '2-HIGH' THEN 1
      #|    ELSE 0
      #|  END) AS high_line_count,
      #|  sum(CASE
      #|    WHEN o_orderpriority <> '1-URGENT' 
      #|    AND o_orderpriority <> '2-HIGH' THEN 1
      #|    ELSE 0
      #|  END) AS low_line_count
      #|FROM
      #|  orders,
      #|  lineitem
      #|WHERE
      #|  o_orderkey = l_orderkey 
      #|  AND l_shipmode IN ('MAIL', 'SHIP') 
      #|  AND l_commitdate < l_receiptdate 
      #|  AND l_shipdate < l_commitdate 
      #|  AND l_receiptdate >= DATE '1994-01-01' 
      #|  AND l_receiptdate < DATE '1994-01-01' + INTERVAL '1' YEAR
      #|GROUP BY
      #|  l_shipmode
      #|ORDER BY
      #|  l_shipmode;
    ),
  )
}

///|
test "TPCH 13" {
  let stmt = read_and_parse("src/tests/tpch/13.sql") |> @sqlparser.pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  c_count,
      #|  count(*) AS custdist
      #|FROM
      #|  (
      #|    SELECT
      #|      c_custkey,
      #|      count(o_orderkey)
      #|    FROM
      #|      customer LEFT OUTER JOIN orders
      #|        ON c_custkey = o_custkey 
      #|        AND o_comment NOT LIKE '%special%requests%'
      #|    GROUP BY
      #|      c_custkey
      #|  ) AS c_orders (c_custkey, c_count)
      #|GROUP BY
      #|  c_count
      #|ORDER BY
      #|  custdist DESC,
      #|  c_count DESC;
    ),
  )
}

///|
test "TPCH 14" {
  let stmt = read_and_parse("src/tests/tpch/14.sql") |> @sqlparser.pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  100 * sum(CASE
      #|    WHEN p_type LIKE 'PROMO%' THEN l_extendedprice * (1 - l_discount)
      #|    ELSE 0
      #|  END) / sum(l_extendedprice * (1 - l_discount)) AS promo_revenue
      #|FROM
      #|  lineitem,
      #|  part
      #|WHERE
      #|  l_partkey = p_partkey 
      #|  AND l_shipdate >= DATE '1995-09-01' 
      #|  AND l_shipdate < DATE '1995-09-01' + INTERVAL '1' MONTH;
    ),
  )
}

///|
test "TPCH 15" {
  let stmt = read_and_parse("src/tests/tpch/15.sql") |> @sqlparser.pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE VIEW revenue0 (supplier_no, total_revenue) AS
      #|SELECT
      #|  l_suppkey,
      #|  sum(l_extendedprice * (1 - l_discount))
      #|FROM
      #|  lineitem
      #|WHERE
      #|  l_shipdate >= DATE '1996-01-01' 
      #|  AND l_shipdate < DATE '1996-01-01' + INTERVAL '3' MONTH
      #|GROUP BY
      #|  l_suppkey;
      #|
      #|SELECT
      #|  s_suppkey,
      #|  s_name,
      #|  s_address,
      #|  s_phone,
      #|  total_revenue
      #|FROM
      #|  supplier,
      #|  revenue0
      #|WHERE
      #|  s_suppkey = supplier_no 
      #|  AND total_revenue = (
      #|    SELECT
      #|      max(total_revenue)
      #|    FROM
      #|      revenue0
      #|  )
      #|ORDER BY
      #|  s_suppkey;
      #|
      #|DROP VIEW revenue0;
    ),
  )
}

///|
test "TPCH 16" {
  let stmt = read_and_parse("src/tests/tpch/16.sql") |> @sqlparser.pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  p_brand,
      #|  p_type,
      #|  p_size,
      #|  count(DISTINCT ps_suppkey) AS supplier_cnt
      #|FROM
      #|  partsupp,
      #|  part
      #|WHERE
      #|  p_partkey = ps_partkey 
      #|  AND p_brand <> 'Brand#45' 
      #|  AND p_type NOT LIKE 'MEDIUM POLISHED%' 
      #|  AND p_size IN (49, 14, 23, 45, 19, 3, 36, 9) 
      #|  AND ps_suppkey NOT IN (
      #|    SELECT
      #|      s_suppkey
      #|    FROM
      #|      supplier
      #|    WHERE
      #|      s_comment LIKE '%Customer%Complaints%'
      #|  )
      #|GROUP BY
      #|  p_brand,
      #|  p_type,
      #|  p_size
      #|ORDER BY
      #|  supplier_cnt DESC,
      #|  p_brand,
      #|  p_type,
      #|  p_size;
    ),
  )
}

///|
test "TPCH 17" {
  let stmt = read_and_parse("src/tests/tpch/17.sql") |> @sqlparser.pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  sum(l_extendedprice) / 7 AS avg_yearly
      #|FROM
      #|  lineitem,
      #|  part
      #|WHERE
      #|  p_partkey = l_partkey 
      #|  AND p_brand = 'Brand#23' 
      #|  AND p_container = 'MED BOX' 
      #|  AND l_quantity < (
      #|    SELECT
      #|      0.2 * avg(l_quantity)
      #|    FROM
      #|      lineitem
      #|    WHERE
      #|      l_partkey = p_partkey
      #|  );
    ),
  )
}

///|
test "TPCH 18" {
  let stmt = read_and_parse("src/tests/tpch/18.sql") |> @sqlparser.pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  c_name,
      #|  c_custkey,
      #|  o_orderkey,
      #|  o_orderdate,
      #|  o_totalprice,
      #|  sum(l_quantity)
      #|FROM
      #|  customer,
      #|  orders,
      #|  lineitem
      #|WHERE
      #|  o_orderkey IN (
      #|    SELECT
      #|      l_orderkey
      #|    FROM
      #|      lineitem
      #|    GROUP BY
      #|      l_orderkey
      #|    HAVING
      #|      sum(l_quantity) > 300
      #|  ) 
      #|  AND c_custkey = o_custkey 
      #|  AND o_orderkey = l_orderkey
      #|GROUP BY
      #|  c_name,
      #|  c_custkey,
      #|  o_orderkey,
      #|  o_orderdate,
      #|  o_totalprice
      #|ORDER BY
      #|  o_totalprice DESC,
      #|  o_orderdate;
    ),
  )
}

///|
test "TPCH 19" {
  let stmt = read_and_parse("src/tests/tpch/19.sql") |> @sqlparser.pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  sum(l_extendedprice * (1 - l_discount)) AS revenue
      #|FROM
      #|  lineitem,
      #|  part
      #|WHERE
      #|  (
      #|    p_partkey = l_partkey 
      #|    AND p_brand = 'Brand#12' 
      #|    AND p_container IN ('SM CASE', 'SM BOX', 'SM PACK', 'SM PKG') 
      #|    AND l_quantity >= 1 
      #|    AND l_quantity <= 1 + 10 
      #|    AND p_size BETWEEN 1 AND 5 
      #|    AND l_shipmode IN ('AIR', 'AIR REG') 
      #|    AND l_shipinstruct = 'DELIVER IN PERSON'
      #|  ) 
      #|  OR (
      #|    p_partkey = l_partkey 
      #|    AND p_brand = 'Brand#23' 
      #|    AND p_container IN ('MED BAG', 'MED BOX', 'MED PKG', 'MED PACK') 
      #|    AND l_quantity >= 10 
      #|    AND l_quantity <= 10 + 10 
      #|    AND p_size BETWEEN 1 AND 10 
      #|    AND l_shipmode IN ('AIR', 'AIR REG') 
      #|    AND l_shipinstruct = 'DELIVER IN PERSON'
      #|  ) 
      #|  OR (
      #|    p_partkey = l_partkey 
      #|    AND p_brand = 'Brand#34' 
      #|    AND p_container IN ('LG CASE', 'LG BOX', 'LG PACK', 'LG PKG') 
      #|    AND l_quantity >= 20 
      #|    AND l_quantity <= 20 + 10 
      #|    AND p_size BETWEEN 1 AND 15 
      #|    AND l_shipmode IN ('AIR', 'AIR REG') 
      #|    AND l_shipinstruct = 'DELIVER IN PERSON'
      #|  );
    ),
  )
}

///|
test "TPCH 20" {
  let stmt = read_and_parse("src/tests/tpch/20.sql") |> @sqlparser.pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  s_name,
      #|  s_address
      #|FROM
      #|  supplier,
      #|  nation
      #|WHERE
      #|  s_suppkey IN (
      #|    SELECT
      #|      ps_suppkey
      #|    FROM
      #|      partsupp
      #|    WHERE
      #|      ps_partkey IN (
      #|        SELECT
      #|          p_partkey
      #|        FROM
      #|          part
      #|        WHERE
      #|          p_name LIKE 'forest%'
      #|      ) 
      #|      AND ps_availqty > (
      #|        SELECT
      #|          0.5 * sum(l_quantity)
      #|        FROM
      #|          lineitem
      #|        WHERE
      #|          l_partkey = ps_partkey 
      #|          AND l_suppkey = ps_suppkey 
      #|          AND l_shipdate >= DATE '1994-01-01' 
      #|          AND l_shipdate < DATE '1994-01-01' + INTERVAL '1' YEAR
      #|      )
      #|  ) 
      #|  AND s_nationkey = n_nationkey 
      #|  AND n_name = 'CANADA'
      #|ORDER BY
      #|  s_name;
    ),
  )
}

///|
test "TPCH 20" {
  let stmt = read_and_parse("src/tests/tpch/20.sql") |> @sqlparser.pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  s_name,
      #|  s_address
      #|FROM
      #|  supplier,
      #|  nation
      #|WHERE
      #|  s_suppkey IN (
      #|    SELECT
      #|      ps_suppkey
      #|    FROM
      #|      partsupp
      #|    WHERE
      #|      ps_partkey IN (
      #|        SELECT
      #|          p_partkey
      #|        FROM
      #|          part
      #|        WHERE
      #|          p_name LIKE 'forest%'
      #|      ) 
      #|      AND ps_availqty > (
      #|        SELECT
      #|          0.5 * sum(l_quantity)
      #|        FROM
      #|          lineitem
      #|        WHERE
      #|          l_partkey = ps_partkey 
      #|          AND l_suppkey = ps_suppkey 
      #|          AND l_shipdate >= DATE '1994-01-01' 
      #|          AND l_shipdate < DATE '1994-01-01' + INTERVAL '1' YEAR
      #|      )
      #|  ) 
      #|  AND s_nationkey = n_nationkey 
      #|  AND n_name = 'CANADA'
      #|ORDER BY
      #|  s_name;
    ),
  )
}

///|
test "TPCH 21" {
  let stmt = read_and_parse("src/tests/tpch/21.sql") |> @sqlparser.pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  s_name,
      #|  count(*) AS numwait
      #|FROM
      #|  supplier,
      #|  lineitem AS l1,
      #|  orders,
      #|  nation
      #|WHERE
      #|  s_suppkey = l1.l_suppkey 
      #|  AND o_orderkey = l1.l_orderkey 
      #|  AND o_orderstatus = 'F' 
      #|  AND l1.l_receiptdate > l1.l_commitdate 
      #|  AND EXISTS (
      #|  SELECT
      #|      *
      #|    FROM
      #|      lineitem AS l2
      #|    WHERE
      #|      l2.l_orderkey = l1.l_orderkey 
      #|      AND l2.l_suppkey <> l1.l_suppkey
      #|  ) 
      #|  AND NOT EXISTS (
      #|  SELECT
      #|      *
      #|    FROM
      #|      lineitem AS l3
      #|    WHERE
      #|      l3.l_orderkey = l1.l_orderkey 
      #|      AND l3.l_suppkey <> l1.l_suppkey 
      #|      AND l3.l_receiptdate > l3.l_commitdate
      #|  ) 
      #|  AND s_nationkey = n_nationkey 
      #|  AND n_name = 'SAUDI ARABIA'
      #|GROUP BY
      #|  s_name
      #|ORDER BY
      #|  numwait DESC,
      #|  s_name;
    ),
  )
}

///|
test "TPCH 22" {
  let stmt = read_and_parse("src/tests/tpch/22.sql") |> @sqlparser.pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  cntrycode,
      #|  count(*) AS numcust,
      #|  sum(c_acctbal) AS totacctbal
      #|FROM
      #|  (
      #|    SELECT
      #|      SUBSTRING(c_phone FROM 1 FOR 2) AS cntrycode,
      #|      c_acctbal
      #|    FROM
      #|      customer
      #|    WHERE
      #|      SUBSTRING(c_phone FROM 1 FOR 2) IN ('13', '31', '23', '29', '30', '18', '17') 
      #|      AND c_acctbal > (
      #|        SELECT
      #|          avg(c_acctbal)
      #|        FROM
      #|          customer
      #|        WHERE
      #|          c_acctbal > 0 
      #|          AND SUBSTRING(c_phone FROM 1 FOR 2) IN ('13', '31', '23', '29', '30', '18', '17')
      #|      ) 
      #|      AND NOT EXISTS (
      #|      SELECT
      #|          *
      #|        FROM
      #|          orders
      #|        WHERE
      #|          o_custkey = c_custkey
      #|      )
      #|  ) AS custsale
      #|GROUP BY
      #|  cntrycode
      #|ORDER BY
      #|  cntrycode;
    ),
  )
}
