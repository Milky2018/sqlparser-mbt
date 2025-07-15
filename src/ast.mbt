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
impl Show for SelectStmt with output(self, logger) {
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
impl Show for Projection with output(self, logger) {
  self.pretty().output(logger)
}

///|
pub(all) enum Expr {
  Identifier(String)
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
} derive(Eq)

///|
impl @pp.Pretty for Expr with pretty(self) {
  match self {
    Expr::Identifier(name) => @pp.text(name)
    Expr::Literal(lit) => lit.pretty()
    Expr::BinaryOperation(left, op, right) =>
      left.pretty() + @pp.space + op.pretty() + @pp.space + right.pretty()
    Expr::UnaryOperation(op, expr) =>
      @pp.group(@pp.text("\{op} ") + expr.pretty())
    Expr::FunctionCall(name, args) =>
      @pp.text(name) +
      @pp.char('(') +
      @pp.separate(@pp.char(',') + @pp.hardline, args.map(@pp.pretty)) +
      @pp.char(')')
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
      @pp.nest(
        @pp.char('(') +
        @pp.hardline +
        stmt.pretty() +
        @pp.hardline +
        @pp.char(')'),
      )
    Expr::Exists(positive~, stmt) =>
      if positive {
        @pp.text("EXISTS (") +
        @pp.hardline +
        @pp.nest(stmt.pretty()) +
        @pp.hardline +
        @pp.char(')')
      } else {
        @pp.text("NOT EXISTS (") +
        @pp.hardline +
        @pp.nest(stmt.pretty()) +
        @pp.hardline +
        @pp.char(')')
      }
  }
}

///|
impl Show for Expr with output(self, logger) {
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
impl Show for Literal with output(self, logger) {
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
    BinaryOperator::Neq => @pp.text("!=")
    BinaryOperator::Lt => @pp.text("<")
    BinaryOperator::Gt => @pp.text(">")
    BinaryOperator::LtEq => @pp.text("<=")
    BinaryOperator::GtEq => @pp.text(">=")
    BinaryOperator::Spaceship => @pp.text("<=>")
    BinaryOperator::Plus => @pp.text("+")
    BinaryOperator::Minus => @pp.text("-")
    BinaryOperator::Mul => @pp.char('*')
    BinaryOperator::Div => @pp.text("/")
    BinaryOperator::Mod => @pp.text("%")
    BinaryOperator::And => @pp.hardline + @pp.text("AND")
    BinaryOperator::Or => @pp.hardline + @pp.text("OR")
  }
}

///|
impl Show for BinaryOperator with output(self, logger) {
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
impl Show for UnaryOperator with output(self, logger) {
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
impl Show for OrderByExpr with output(self, logger) {
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
      @pp.nest(
        @pp.char('(') +
        @pp.hardline +
        @pp.nest(stmt.pretty()) +
        @pp.hardline +
        @pp.char(')') +
        (match alias_name_option {
          Some(alias_name) => @pp.text(" AS ") + @pp.text(alias_name)
          None => @pp.empty
        }),
      )
  }
}

///|
impl Show for TableRef with output(self, logger) {
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
impl Show for IntervalQualifier with output(self, logger) {
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
impl Show for PrimaryDatetimeField with output(self, logger) {
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
impl Show for DatetimeUnit with output(self, logger) {
  self.pretty().output(logger)
}
