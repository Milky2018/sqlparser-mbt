///|
pub(all) enum Statement {
  Select(SelectStmt)
  // Insert(InsertStmt)
  // Update(UpdateStmt)
  // Delete(DeleteStmt)
} derive(Eq)

///|
impl @pp.Pretty for Statement with pretty(self) {
  (match self {
    Statement::Select(stmt) => stmt.pretty()
    // Statement::Insert(stmt) => @pp.text("Insert: \{stmt}")
    // Statement::Update(stmt) => @pp.text("Update: \{stmt}")
    // Statement::Delete(stmt) => @pp.text("Delete: \{stmt}")
  }) +
  @pp.text(";")
}

///|
pub impl Show for Statement with output(self, logger) {
  self.pretty().output(logger)
}

///|
pub struct SelectStmt {
  // SELECT <projections>
  projections : Array[Projection]
  // FROM <table_refs>
  from : Array[TableRef]
  // WHERE <where_clause>
  where_clause : Expr?
  // GROUP BY <group_by>
  group_by : Array[Expr]
  // HAVING <expr>
  having : Expr?
  // ORDER BY <order_by>
  order_by : Array[OrderByExpr]
  limit : Int?
  offset : Int?
} derive(Eq)

///|
impl @pp.Pretty for SelectStmt with pretty(self) {
  @pp.text("SELECT") +
  @pp.nest(
    @pp.hardline +
    @pp.separate(@pp.char(',') + @pp.hardline, self.projections.map(@pp.pretty)),
  ) +
  @pp.hardline +
  @pp.text("FROM") +
  @pp.nest(
    @pp.hardline +
    @pp.separate(@pp.char(',') + @pp.hardline, self.from.map(@pp.pretty)),
  ) +
  (match self.where_clause {
    Some(selection) =>
      @pp.hardline +
      @pp.text("WHERE") +
      @pp.nest(@pp.hardline + selection.pretty())
    None => @pp.empty
  }) +
  (if self.group_by.length() > 0 {
    @pp.hardline +
    @pp.text("GROUP BY") +
    @pp.nest(
      @pp.hardline +
      @pp.separate(@pp.char(',') + @pp.hardline, self.group_by.map(@pp.pretty)),
    )
  } else {
    @pp.text("")
  }) +
  (match self.having {
    Some(expr) =>
      @pp.hardline + @pp.text("HAVING") + @pp.nest(@pp.hardline + expr.pretty())
    None => @pp.empty
  }) +
  (if self.order_by.length() > 0 {
    @pp.hardline +
    @pp.text("ORDER BY") +
    @pp.nest(
      @pp.hardline +
      @pp.separate(@pp.char(',') + @pp.hardline, self.order_by.map(@pp.pretty)),
    )
  } else {
    @pp.text("")
  })
}

///|
pub impl Show for SelectStmt with output(self, logger) {
  self.pretty().output(logger)
}

///|
pub(all) enum Projection {
  Wildcard
  UnamedExpr(Expr)
  AliasedExpr(Expr, String)
} derive(Eq)

///|
impl @pp.Pretty for Projection with pretty(self) {
  match self {
    Projection::Wildcard => @pp.char('*')
    Projection::UnamedExpr(expr) => expr.pretty()
    Projection::AliasedExpr(expr, alias_name) =>
      expr.pretty() + @pp.text(" AS ") + @pp.text(alias_name)
  }
}

///|
pub impl Show for Projection with output(self, logger) {
  self.pretty().output(logger)
}

///|
pub(all) enum Expr {
  // <identifier>
  Identifier(String)
  // <identifier>.<identifier>
  CompoundIdentifier(Array[String])
  // string, integer, double, boolean, null
  Literal(Literal)
  // <expr> + <expr>
  BinaryOperation(Expr, BinaryOperator, Expr)
  // - <expr>
  UnaryOperation(UnaryOperator, Expr)
  // sum(*)
  FunctionCall(String, Array[Expr])
  // *
  Wildcard
  // DATE '1998-05-19'
  Datetime(String)
  // INTERVAL '1 day' YEAR TO MONTH
  Interval(String, IntervalQualifier)
  // <expr> [NOT] LIKE <expr>
  Like(positive~ : Bool, Expr, Expr)
  // <expr> [NOT] ILIKE <expr>
  ILike(positive~ : Bool, Expr, Expr)
  // (SELECT ...)
  SubQuery(SelectStmt)
  // [NOT] EXISTS
  Exists(positive~ : Bool, SelectStmt)
  // <expr> [NOT] BETWEEN <expr> AND <expr>
  Between(positive~ : Bool, Expr, Expr, Expr)
  // EXTRACT(YEAR FROM <expr>)
  Extract(PrimaryDatetimeField, Expr)
  // CASE [operand] WHEN <expr> THEN <expr> [...] [ELSE <expr>] END
  Case(CaseExpr)
  // <expr> [NOT] IN (<expr>, ...)
  InList(positive~ : Bool, Expr, Array[Expr])
  // <expr> [NOT] IN (SELECT ...)
  InSubQuery(positive~ : Bool, Expr, SelectStmt)
} derive(Eq)

///|
fn wrap_parens(expr : Expr, current_op : BinaryOperator) -> @pp.Document {
  if expr is Expr::BinaryOperation(_, Or, _) {
    @pp.parens(@pp.nest(@pp.hardline + expr.pretty()) + @pp.hardline)
  } else if expr is Expr::BinaryOperation(_, op, _) &&
    op.get_precedence().value() < current_op.get_precedence().value() {
    @pp.parens(expr.pretty())
  } else {
    expr.pretty()
  }
}

///|
impl @pp.Pretty for Expr with pretty(self) {
  match self {
    Expr::Identifier(name) => @pp.text(name)
    Expr::CompoundIdentifier(parts) =>
      @pp.separate(@pp.text("."), parts.map(@pp.text))
    Expr::Literal(lit) => lit.pretty()
    Expr::BinaryOperation(left, op, right) =>
      wrap_parens(left, op) +
      @pp.space +
      op.pretty() +
      @pp.space +
      wrap_parens(right, op)
    Expr::UnaryOperation(op, expr) =>
      @pp.group(@pp.text("\{op} ") + expr.pretty())
    Expr::FunctionCall(name, args) =>
      @pp.text(name) +
      @pp.parens(@pp.separate(@pp.text(", "), args.map(@pp.pretty)))
    Expr::Wildcard => @pp.char('*')
    Datetime(s) => @pp.text("DATE '") + @pp.text(s) + @pp.char('\'')
    Interval(s, qualifier) =>
      @pp.text("INTERVAL '") + @pp.text(s) + @pp.text("' ") + qualifier.pretty()
    Expr::Like(positive~, left, right) =>
      left.pretty() +
      @pp.text(if positive { "" } else { " NOT" }) +
      @pp.text(" LIKE ") +
      right.pretty()
    Expr::ILike(positive~, left, right) =>
      left.pretty() +
      @pp.text(if positive { "" } else { " NOT" }) +
      @pp.text(" ILIKE ") +
      right.pretty()
    Expr::SubQuery(stmt) =>
      @pp.parens(@pp.nest(@pp.hardline + stmt.pretty()) + @pp.hardline)
    Expr::Exists(positive~, stmt) =>
      (if positive { @pp.text("EXISTS (") } else { @pp.text("NOT EXISTS (") }) +
      @pp.hardline +
      @pp.nest(stmt.pretty()) +
      @pp.hardline +
      @pp.char(')')
    Expr::Between(positive~, e, low, hi) =>
      e.pretty() +
      @pp.text(if positive { " BETWEEN " } else { " NOT BETWEEN " }) +
      low.pretty() +
      @pp.text(" AND ") +
      hi.pretty()
    Expr::Extract(field, expr) =>
      @pp.text("EXTRACT(") +
      field.pretty() +
      @pp.text(" FROM ") +
      expr.pretty() +
      @pp.char(')')
    Expr::Case(case_expr) => case_expr.pretty()
    Expr::InList(positive~, expr, items) =>
      expr.pretty() +
      @pp.text(if positive { " IN (" } else { " NOT IN (" }) +
      @pp.separate(@pp.text(", "), items.map(@pp.pretty)) +
      @pp.char(')')
    Expr::InSubQuery(positive~, expr, sub_query) =>
      expr.pretty() +
      @pp.text(if positive { " IN (" } else { " NOT IN (" }) +
      @pp.nest(@pp.hardline + sub_query.pretty()) + @pp.hardline +
      @pp.char(')')
  }
}

///|
pub impl Show for Expr with output(self, logger) {
  self.pretty().output(logger)
}

///|
pub(all) enum Literal {
  Integer(Int)
  Double(Double) // TODO: float32
  String(String)
  Boolean(Bool)
  Null
} derive(Eq)

///|
impl @pp.Pretty for Literal with pretty(self) {
  match self {
    Literal::Integer(value) => @pp.text("\{value}")
    Literal::Double(value) => @pp.text("\{value}")
    Literal::String(value) => @pp.text("'\{value}'")
    Literal::Boolean(value) => @pp.text(if value { "TRUE" } else { "FALSE" })
    Literal::Null => @pp.text("NULL")
  }
}

///|
pub impl Show for Literal with output(self, logger) {
  self.pretty().output(logger)
}

///|
pub(all) enum BinaryOperator {
  Eq
  Neq
  Lt
  Gt
  LtEq
  GtEq
  Spaceship
  Plus
  Minus
  Mul
  Div
  Mod
  And
  Or
} derive(Eq)

///|
impl @pp.Pretty for BinaryOperator with pretty(self) {
  match self {
    BinaryOperator::Eq => @pp.text("=")
    BinaryOperator::Neq => @pp.text("<>")
    BinaryOperator::Lt => @pp.text("<")
    BinaryOperator::Gt => @pp.text(">")
    BinaryOperator::LtEq => @pp.text("<=")
    BinaryOperator::GtEq => @pp.text(">=")
    BinaryOperator::Spaceship => @pp.text("<=>")
    BinaryOperator::Plus => @pp.text("+")
    BinaryOperator::Minus => @pp.text("-")
    BinaryOperator::Mul => @pp.text("*")
    BinaryOperator::Div => @pp.text("/")
    BinaryOperator::Mod => @pp.text("%")
    BinaryOperator::And => @pp.hardline + @pp.text("AND")
    BinaryOperator::Or => @pp.hardline + @pp.text("OR")
  }
}

///|
pub impl Show for BinaryOperator with output(self, logger) {
  self.pretty().output(logger)
}

///|
pub(all) enum UnaryOperator {
  Negate
  Not
} derive(Eq)

///|
impl @pp.Pretty for UnaryOperator with pretty(self) {
  match self {
    UnaryOperator::Negate => @pp.text("-")
    UnaryOperator::Not => @pp.text("NOT ")
  }
}

///|
pub impl Show for UnaryOperator with output(self, logger) {
  self.pretty().output(logger)
}

///|
pub struct OrderByExpr {
  // ORDER BY <expr>
  expr : Expr
  // ASC | DESC
  asc : Bool?
  // NULLS FIRST | NULLS LAST
  nulls_first : Bool?
} derive(Eq)

///|
impl @pp.Pretty for OrderByExpr with pretty(self) {
  self.expr.pretty() +
  (match self.asc {
    Some(true) => @pp.text(" ASC")
    Some(false) => @pp.text(" DESC")
    None => @pp.text("")
  }) +
  (match self.nulls_first {
    Some(true) => @pp.text(" NULLS FIRST")
    Some(false) => @pp.text(" NULLS LAST")
    None => @pp.text("")
  })
}

///|
pub impl Show for OrderByExpr with output(self, logger) {
  self.pretty().output(logger)
}

///|
pub(all) enum TableRef {
  // FROM table [AS alias]
  Table(String, String?)
  // FROM (SELECT ...) [AS alias]
  SubQuery(SelectStmt, String?)
} derive(Eq)

///|
impl @pp.Pretty for TableRef with pretty(self) {
  match self {
    TableRef::Table(name, None) => @pp.text(name)
    TableRef::Table(name, Some(alias_name)) =>
      @pp.text(name) + @pp.text(" AS ") + @pp.text(alias_name)
    TableRef::SubQuery(stmt, alias_name_option) =>
      @pp.parens(@pp.nest(@pp.hardline + stmt.pretty()) + @pp.hardline) +
      (match alias_name_option {
        Some(alias_name) => @pp.text(" AS ") + @pp.text(alias_name)
        None => @pp.empty
      })
  }
}

///|
pub impl Show for TableRef with output(self, logger) {
  self.pretty().output(logger)
}

///|
pub(all) enum IntervalQualifier {
  // YEAR, MONTH, DAY, HOUR, MINUTE, SECOND
  Single(PrimaryDatetimeField)
  // <from> TO <to>
  Range(PrimaryDatetimeField, PrimaryDatetimeField)
} derive(Eq)

///|
impl @pp.Pretty for IntervalQualifier with pretty(self) {
  match self {
    IntervalQualifier::Single(field) => field.pretty()
    IntervalQualifier::Range(from, to) =>
      @pp.group(from.pretty() + @pp.text(" TO ") + to.pretty())
  }
}

///|
pub impl Show for IntervalQualifier with output(self, logger) {
  self.pretty().output(logger)
}

///|
struct PrimaryDatetimeField {
  // YEAR, MONTH, DAY, HOUR, MINUTE, SECOND
  field : DatetimeUnit
  // (3)
  precision : Int?
} derive(Eq)

///|
impl @pp.Pretty for PrimaryDatetimeField with pretty(self) {
  self.field.pretty() +
  @pp.group(
    if self.precision is Some(p) {
      @pp.text(" (\{p})")
    } else {
      @pp.text("")
    },
  )
}

///|
pub impl Show for PrimaryDatetimeField with output(self, logger) {
  self.pretty().output(logger)
}

///|
pub(all) enum DatetimeUnit {
  Year
  Month
  Day
  Hour
  Minute
  Second
} derive(Eq)

///|
impl @pp.Pretty for DatetimeUnit with pretty(self) {
  match self {
    DatetimeUnit::Year => @pp.text("YEAR")
    DatetimeUnit::Month => @pp.text("MONTH")
    DatetimeUnit::Day => @pp.text("DAY")
    DatetimeUnit::Hour => @pp.text("HOUR")
    DatetimeUnit::Minute => @pp.text("MINUTE")
    DatetimeUnit::Second => @pp.text("SECOND")
  }
}

///|
pub impl Show for DatetimeUnit with output(self, logger) {
  self.pretty().output(logger)
}

// CASE [operand] WHEN <expr> THEN <expr> [...] [ELSE <expr>] END

///|
pub struct CaseExpr {
  // CASE [operand]
  operand : Expr?
  // WHEN <expr> THEN <expr> [...]
  when_then_clauses : Array[(Expr, Expr)]
  // ELSE <expr>
  else_expr : Expr?
} derive(Eq)

///|
impl @pp.Pretty for CaseExpr with pretty(self) {
  @pp.text("CASE") +
  (match self.operand {
    Some(op) => @pp.space + op.pretty()
    None => @pp.empty
  }) +
  @pp.nest(
    @pp.hardline +
    @pp.separate(
      @pp.hardline,
      self.when_then_clauses.map(fn(condition_result) {
        let condition = condition_result.0
        let result = condition_result.1
        @pp.text("WHEN ") +
        condition.pretty() +
        @pp.text(" THEN ") +
        result.pretty()
      }),
    ) +
    (match self.else_expr {
      Some(else_expr) => @pp.hardline + @pp.text("ELSE ") + else_expr.pretty()
      None => @pp.empty
    }),
  ) +
  @pp.hardline +
  @pp.text("END")
}

///|
pub impl Show for CaseExpr with output(self, logger) {
  self.pretty().output(logger)
}

///|
test "Case when" {
  let expr = {
    operand: Some(Expr::Identifier("x")),
    when_then_clauses: [
      (Expr::Identifier("a"), Expr::Identifier("b")),
      (Expr::Identifier("c"), Expr::Identifier("d")),
    ],
    else_expr: Some(Expr::Identifier("e")),
  }
  inspect(
    expr,
    content=(
      #|CASE x
      #|  WHEN a THEN b
      #|  WHEN c THEN d
      #|  ELSE e
      #|END
    ),
  )
}
