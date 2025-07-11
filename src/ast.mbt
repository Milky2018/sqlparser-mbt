///|
pub(all) enum Statement {
  Select(SelectStmt)
  // Insert(InsertStmt)
  // Update(UpdateStmt)
  // Delete(DeleteStmt)
} derive(Eq)

///|
pub impl Show for Statement with output(self, logger) {
  match self {
    Statement::Select(stmt) => stmt.output(logger)
    // Statement::Insert(stmt) => logger.write("Insert: \{stmt}"),
    // Statement::Update(stmt) => logger.write("Update: \{stmt}"),
    // Statement::Delete(stmt) => logger.write("Delete: \{stmt}"),
  }
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
impl Show for SelectStmt with output(self, logger) {
  logger.write_string("SELECT ")
  for i = 0; i < self.projections.length(); i = i + 1 {
    if i > 0 {
      logger.write_string(", ")
    }
    self.projections[i].output(logger)
  }
  logger.write_string(" FROM ")
  for i = 0; i < self.from.length(); i = i + 1 {
    if i > 0 {
      logger.write_string(", ")
    }
    self.from[i].output(logger)
  }
  if self.where_clause is Some(selection) {
    logger.write_string(" WHERE ")
    selection.output(logger)
  }
  if self.order_by.length() > 0 {
    logger.write_string(" ORDER BY ")
    for i = 0; i < self.order_by.length(); i = i + 1 {
      if i > 0 {
        logger.write_string(", ")
      }
      self.order_by[i].output(logger)
    }
  }
  logger.write_string(";")
}

///|
pub(all) enum Projection {
  Wildcard
  UnamedExpr(Expr)
  AliasedExpr(Expr, String)
} derive(Eq)

///|
impl Show for Projection with output(self, logger) {
  match self {
    Projection::Wildcard => logger.write_string("*")
    Projection::UnamedExpr(expr) => expr.output(logger)
    Projection::AliasedExpr(expr, alias_name) => {
      expr.output(logger)
      logger.write_string(" AS ")
      logger.write_string(alias_name)
    }
  }
}

///|
pub(all) enum Expr {
  Identifier(String)
  Literal(Literal)
  BinaryOperation(Expr, BinaryOperator, Expr)
  UnaryOperation(UnaryOperator, Expr)
  FunctionCall(String, Array[Expr])
  Wildcard
  // DATE '1998-05-19'
  // TODO: parse the date string
  Datetime(String)
  // INTERVAL '1 day' YEAR TO MONTH
  Interval(String, IntervalQualifier)
} derive(Eq)

///|
impl Show for Expr with output(self, logger) {
  match self {
    Expr::Identifier(name) => logger.write_string(name)
    Expr::Literal(lit) => lit.output(logger)
    Expr::BinaryOperation(left, op, right) => {
      logger.write_string("(")
      left.output(logger)
      logger.write_string(" \{op} ")
      right.output(logger)
      logger.write_string(")")
    }
    Expr::UnaryOperation(op, expr) => {
      logger.write_string("\{op} ")
      expr.output(logger)
    }
    Expr::FunctionCall(name, args) => {
      logger.write_string(name)
      logger.write_string("(")
      for i = 0; i < args.length(); i = i + 1 {
        if i > 0 {
          logger.write_string(", ")
        }
        args[i].output(logger)
      }
      logger.write_string(")")
    }
    Expr::Wildcard => logger.write_string("*")
    Datetime(s) => {
      logger.write_string("DATE '")
      logger.write_string(s)
      logger.write_string("'")
    }
    Interval(s, qualifier) => {
      logger.write_string("INTERVAL '")
      logger.write_string(s)
      logger.write_string("' ")
      qualifier.output(logger)
    }
  }
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
impl Show for Literal with output(self, logger) {
  match self {
    Literal::Integer(value) => logger.write_string("\{value}")
    Literal::Double(value) => logger.write_string("\{value}")
    Literal::String(value) => logger.write_string("\"" + value + "\"")
    Literal::Boolean(value) =>
      logger.write_string(if value { "TRUE" } else { "FALSE" })
    Literal::Null => logger.write_string("NULL")
  }
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
} derive(Eq)

///|
impl Show for BinaryOperator with output(self, logger) {
  match self {
    BinaryOperator::Eq => logger.write_string("=")
    BinaryOperator::Neq => logger.write_string("!=")
    BinaryOperator::Lt => logger.write_string("<")
    BinaryOperator::Gt => logger.write_string(">")
    BinaryOperator::LtEq => logger.write_string("<=")
    BinaryOperator::GtEq => logger.write_string(">=")
    BinaryOperator::Spaceship => logger.write_string("<=>")
    BinaryOperator::Plus => logger.write_string("+")
    BinaryOperator::Minus => logger.write_string("-")
    BinaryOperator::Mul => logger.write_string("*")
    BinaryOperator::Div => logger.write_string("/")
    BinaryOperator::Mod => logger.write_string("%")
  }
}

///|
pub(all) enum UnaryOperator {
  Negate
  Not
} derive(Eq)

///|
impl Show for UnaryOperator with output(self, logger) {
  match self {
    UnaryOperator::Negate => logger.write_string("-")
    UnaryOperator::Not => logger.write_string("NOT ")
  }
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
impl Show for OrderByExpr with output(self, logger) {
  self.expr.output(logger)
  if self.asc is Some(b) {
    logger.write_string(
      match b {
        true => " ASC"
        false => " DESC"
      },
    )
  }
  if self.nulls_first is Some(b) {
    logger.write_string(
      match b {
        true => " NULLS FIRST"
        false => " NULLS LAST"
      },
    )
  }
}

///|
pub(all) enum Asc {
  Ascending
  Descending
} derive(Eq)

///|
pub(all) enum TableRef {
  Table(String)
  TableAlias(String, String)
  SubQuery(SelectStmt, String)
} derive(Eq)

///|
impl Show for TableRef with output(self, logger) {
  match self {
    TableRef::Table(name) => logger.write_string(name)
    TableRef::TableAlias(name, alias_name) => {
      logger.write_string(name)
      logger.write_string(" AS ")
      logger.write_string(alias_name)
    }
    TableRef::SubQuery(stmt, alias_name) => {
      logger.write_string("(")
      stmt.output(logger)
      logger.write_string(") AS ")
      logger.write_string(alias_name)
    }
  }
}

///|
pub(all) enum IntervalQualifier {
  // YEAR, MONTH, DAY, HOUR, MINUTE, SECOND
  Single(PrimaryDatetimeField)
  // <from> TO <to>
  Range(PrimaryDatetimeField, PrimaryDatetimeField)
} derive(Eq)

struct PrimaryDatetimeField {
  // YEAR, MONTH, DAY, HOUR, MINUTE, SECOND
  field : DatetimeUnit
  // (3)
  precision : Int?
} derive(Eq)

impl Show for PrimaryDatetimeField with output(self, logger) {
  self.field.output(logger)
  if self.precision is Some(p) {
    logger.write_string(" (\{p})")
  }
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
impl Show for DatetimeUnit with output(self, logger) {
  match self {
    DatetimeUnit::Year => logger.write_string("YEAR")
    DatetimeUnit::Month => logger.write_string("MONTH")
    DatetimeUnit::Day => logger.write_string("DAY")
    DatetimeUnit::Hour => logger.write_string("HOUR")
    DatetimeUnit::Minute => logger.write_string("MINUTE")
    DatetimeUnit::Second => logger.write_string("SECOND")
  }
}

///|
impl Show for IntervalQualifier with output(self, logger) {
  match self {
    IntervalQualifier::Single(field) => field.output(logger)
    IntervalQualifier::Range(from, to) => {
      from.output(logger)
      logger.write_string(" TO ")
      to.output(logger)
    }
  }
}
