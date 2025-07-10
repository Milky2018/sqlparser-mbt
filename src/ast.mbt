///|
pub(all) enum Statement {
  Select(SelectStmt)
  // Insert(InsertStmt)
  // Update(UpdateStmt)
  // Delete(DeleteStmt)
} derive(Eq)

///|
impl Show for Statement with output(self, logger) {
  match self {
    Statement::Select(stmt) => stmt.output(logger)
    // Statement::Insert(stmt) => logger.write("Insert: \{stmt}"),
    // Statement::Update(stmt) => logger.write("Update: \{stmt}"),
    // Statement::Delete(stmt) => logger.write("Delete: \{stmt}"),
  }
}

///|
pub struct SelectStmt {
  projections : Array[Projection]
  from : Array[TableRef]
  where_clause : Expr?
  group_by : Array[Expr]
  having : Expr?
  order_by : Array[OrderBy]
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
} derive(Eq, Show)

///|
pub(all) enum Literal {
  Integer(Int)
  Double(Double) // TODO: float32
  String(String)
  Boolean(Bool)
  Null
} derive(Eq, Show)

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
} derive(Eq, Show)

///|
pub(all) enum UnaryOperator {
  Negate
  Not
} derive(Eq, Show)

///|
pub struct OrderBy {
  expr : Expr
  asc : Asc
} derive(Eq, Show)

///|
pub(all) enum Asc {
  Ascending
  Descending
} derive(Eq, Show)

///|
pub(all) enum TableRef {
  Table(String)
  TableAlias(String, String)
  SubQuery(SelectStmt, String)
} derive(Eq, Show)
