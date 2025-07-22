///|
pub struct Statements {
  /// The list of SQL statements parsed from the input.
  stmts : Array[Statement]
}

///|
impl @pp.Pretty for Statements with pretty(self) {
  @pp.separate(@pp.hardline + @pp.hardline, self.stmts.map(@pp.pretty))
}

///|
pub impl Show for Statements with output(self, logger) {
  self.pretty().output(logger)
}

///|
pub fn Statements::op_get(self : Self, index : Int) -> Statement {
  self.stmts[index]
}

///|
pub enum Statement {
  Select(SelectStmt)
  // Insert(InsertStmt)
  // Update(UpdateStmt)
  // Delete(DeleteStmt)
  CreateTable(CreateTableStmt)
  CreateView(CreateViewStmt)
  DropView(DropViewStmt)
} derive(Eq)

///|
impl @pp.Pretty for Statement with pretty(self) {
  (match self {
    Statement::Select(stmt) => stmt.pretty()
    // Statement::Insert(stmt) => @pp.text("Insert: \{stmt}")
    // Statement::Update(stmt) => @pp.text("Update: \{stmt}")
    // Statement::Delete(stmt) => @pp.text("Delete: \{stmt}")
    CreateTable(stmt) => stmt.pretty()
    CreateView(stmt) => stmt.pretty()
    DropView(stmt) => stmt.pretty()
  }) +
  @pp.text(";")
}

///|
pub impl Show for Statement with output(self, logger) {
  self.pretty().output(logger)
}

///|
pub struct SelectStmt {
  /// SELECT <projections>
  projections : Array[Projection]
  /// FROM <table_refs>
  from : Array[TableRef]
  /// WHERE <where_clause>
  where_clause : Expr?
  /// GROUP BY <group_by>
  group_by : Array[Expr]
  /// HAVING <expr>
  having : Expr?
  /// ORDER BY <order_by>
  order_by : Array[OrderByExpr]
  limit : Expr?
  offset : Expr?
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
  }) +
  (match self.limit {
    Some(expr) =>
      @pp.hardline + @pp.text("LIMIT") + @pp.nest(@pp.hardline + expr.pretty())
    None => @pp.empty
  }) +
  (match self.offset {
    Some(expr) =>
      @pp.hardline + @pp.text("OFFSET") + @pp.nest(@pp.hardline + expr.pretty())
    None => @pp.empty
  })
}

///|
pub impl Show for SelectStmt with output(self, logger) {
  self.pretty().output(logger)
}

///|
pub enum Projection {
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
pub enum Expr {
  /// <identifier>
  Identifier(String)
  /// <identifier>.<identifier>
  CompoundIdentifier(Array[String])
  /// string, integer, double, boolean, null
  Literal(Literal)
  /// <expr> + <expr>
  BinaryOperation(Expr, BinaryOperator, Expr)
  /// - <expr>
  UnaryOperation(UnaryOperator, Expr)
  /// sum(*)
  FunctionCall(String, DuplicateTreatment?, Array[Expr])
  /// *
  Wildcard
  /// DATE '1998-05-19'
  Datetime(String)
  /// INTERVAL '1 day' YEAR TO MONTH
  Interval(String, IntervalQualifier)
  /// <expr> [NOT] LIKE <expr>
  Like(positive~ : Bool, Expr, Expr)
  /// <expr> [NOT] ILIKE <expr>
  ILike(positive~ : Bool, Expr, Expr)
  /// (SELECT ...)
  SubQuery(SelectStmt)
  /// [NOT] EXISTS
  Exists(positive~ : Bool, SelectStmt)
  /// <expr> [NOT] BETWEEN <expr> AND <expr>
  Between(positive~ : Bool, Expr, Expr, Expr)
  /// EXTRACT(YEAR FROM <expr>)
  Extract(PrimaryDatetimeField, Expr)
  /// CASE [operand] WHEN <expr> THEN <expr> [...] [ELSE <expr>] END
  Case(CaseExpr)
  /// <expr> [NOT] IN (<expr>, ...)
  InList(positive~ : Bool, Expr, Array[Expr])
  /// <expr> [NOT] IN (SELECT ...)
  InSubQuery(positive~ : Bool, Expr, SelectStmt)
} derive(Eq)

///|
fn wrap_parens(expr : Expr, current_op : BinaryOperator) -> @pp.Document {
  if current_op == BinaryOperator::Or &&
    expr is Expr::BinaryOperation(_, And, _) {
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
    Expr::UnaryOperation(op, expr) => op.pretty() + expr.pretty()
    Expr::FunctionCall(name, dup, args) =>
      @pp.text(name) +
      @pp.parens(
        (if dup is Some(dup) { dup.pretty() + @pp.space } else { @pp.empty }) +
        @pp.separate(@pp.text(", "), args.map(@pp.pretty)),
      )
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
      @pp.nest(@pp.hardline + sub_query.pretty()) +
      @pp.hardline +
      @pp.char(')')
  }
}

///|
pub impl Show for Expr with output(self, logger) {
  self.pretty().output(logger)
}

///|
pub enum Literal {
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
pub enum BinaryOperator {
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
pub enum UnaryOperator {
  Plus
  Minus
  Not
} derive(Eq)

///|
impl @pp.Pretty for UnaryOperator with pretty(self) {
  match self {
    UnaryOperator::Plus => @pp.text("+")
    UnaryOperator::Minus => @pp.text("-")
    UnaryOperator::Not => @pp.text("NOT ")
  }
}

///|
pub impl Show for UnaryOperator with output(self, logger) {
  self.pretty().output(logger)
}

///|
pub struct OrderByExpr {
  /// ORDER BY <expr>
  expr : Expr
  /// ASC | DESC
  asc : Bool?
  /// NULLS FIRST | NULLS LAST
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
pub struct TableRef {
  factor : TableFactor
  joins : Array[Join]
} derive(Eq)

///|
impl @pp.Pretty for TableRef with pretty(self) {
  self.factor.pretty() +
  @pp.separate_map(@pp.hardline, self.joins, fn(join) { join.pretty() })
}

///|
pub impl Show for TableRef with output(self, logger) {
  self.pretty().output(logger)
}

///|
pub enum TableFactor {
  /// <col_name> [AS <alias>]
  Column(String, TableAlias?)
  /// FROM (SELECT ...) [AS <alias>]
  SubQuery(SelectStmt, TableAlias?)
} derive(Eq)

///|
impl @pp.Pretty for TableFactor with pretty(self) {
  match self {
    TableFactor::Column(name, alias_name) =>
      @pp.text(name) +
      (match alias_name {
        Some(a) => a.pretty()
        None => @pp.empty
      })
    TableFactor::SubQuery(stmt, alias_name) =>
      @pp.parens(@pp.nest(@pp.hardline + stmt.pretty()) + @pp.hardline) +
      (match alias_name {
        Some(a) => a.pretty()
        None => @pp.empty
      })
  }
}

///|
pub impl Show for TableFactor with output(self, logger) {
  self.pretty().output(logger)
}

///|
pub struct TableAlias {
  /// AS <alias>
  name : String
  /// AS <alias> (<col_name>, ...)
  columns : Array[String]
} derive(Eq)

///|
impl @pp.Pretty for TableAlias with pretty(self) {
  @pp.text(" AS ") +
  @pp.text(self.name) +
  (if self.columns.length() > 0 {
    @pp.space +
    @pp.parens(@pp.separate(@pp.text(", "), self.columns.map(@pp.text)))
  } else {
    @pp.empty
  })
}

///|
pub impl Show for TableAlias with output(self, logger) {
  self.pretty().output(logger)
}

///|
pub struct Join {
  /// JOIN <table_ref> ON <expr>
  table_ref : TableRef
  /// LEFT JOIN | RIGHT JOIN | FULL | INNER | CROSS
  join_operator : JoinOperator
} derive(Eq)

///|
impl @pp.Pretty for Join with pretty(self) {
  @pp.space +
  self.join_operator.pretty() +
  @pp.space +
  self.table_ref.pretty() +
  (match self.join_operator {
    JoinOperator::Join(constraint) => constraint.pretty()
    JoinOperator::Left(constraint) => constraint.pretty()
    JoinOperator::Right(constraint) => constraint.pretty()
    JoinOperator::Full(constraint) => constraint.pretty()
    JoinOperator::Inner(constraint) => constraint.pretty()
    JoinOperator::LeftOuter(constraint) => constraint.pretty()
    JoinOperator::RightOuter(constraint) => constraint.pretty()
    JoinOperator::FullOuter(constraint) => constraint.pretty()
    JoinOperator::Cross => @pp.empty
  })
}

///|
pub impl Show for Join with output(self, logger) {
  self.pretty().output(logger)
}

///|
pub enum JoinOperator {
  Join(JoinConstraint)
  Left(JoinConstraint)
  LeftOuter(JoinConstraint)
  Right(JoinConstraint)
  RightOuter(JoinConstraint)
  Full(JoinConstraint)
  FullOuter(JoinConstraint)
  Inner(JoinConstraint)
  Cross
} derive(Eq)

///|
impl @pp.Pretty for JoinOperator with pretty(self) {
  match self {
    JoinOperator::Join(_) => @pp.text("JOIN")
    JoinOperator::Left(_) => @pp.text("LEFT JOIN")
    JoinOperator::LeftOuter(_) => @pp.text("LEFT OUTER JOIN")
    JoinOperator::Right(_) => @pp.text("RIGHT JOIN")
    JoinOperator::RightOuter(_) => @pp.text("RIGHT OUTER JOIN")
    JoinOperator::Full(_) => @pp.text("FULL JOIN")
    JoinOperator::FullOuter(_) => @pp.text("FULL OUTER JOIN")
    JoinOperator::Inner(_) => @pp.text("INNER JOIN")
    JoinOperator::Cross => @pp.text("CROSS JOIN")
  }
}

///|
pub impl Show for JoinOperator with output(self, logger) {
  self.pretty().output(logger)
}

///|
pub enum JoinConstraint {
  /// ON <expr>
  On(Expr)
  /// USING (<col_name>, ...)
  Using(Array[String])
  None
} derive(Eq)

///|
impl @pp.Pretty for JoinConstraint with pretty(self) {
  match self {
    JoinConstraint::On(expr) =>
      @pp.nest(@pp.hardline + @pp.text("ON ") + expr.pretty())
    JoinConstraint::Using(cols) =>
      @pp.nest(
        @pp.hardline +
        @pp.text("USING (") +
        @pp.separate(@pp.text(", "), cols.map(@pp.text)) +
        @pp.char(')'),
      )
    JoinConstraint::None => @pp.empty
  }
}

///|
pub impl Show for JoinConstraint with output(self, logger) {
  self.pretty().output(logger)
}

///|
pub enum IntervalQualifier {
  /// YEAR, MONTH, DAY, HOUR, MINUTE, SECOND
  Single(PrimaryDatetimeField)
  /// <from> TO <to>
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
  /// YEAR, MONTH, DAY, HOUR, MINUTE, SECOND
  field : DatetimeUnit
  /// (3)
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
pub enum DatetimeUnit {
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

///| CASE [operand] WHEN <expr> THEN <expr> [...] [ELSE <expr>] END
pub struct CaseExpr {
  /// CASE [operand]
  operand : Expr?
  /// WHEN <expr> THEN <expr> [...]
  when_then_clauses : Array[(Expr, Expr)]
  /// ELSE <expr>
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

///|
pub struct CreateTableStmt {
  /// CREATE TABLE <table_name>
  name : String
  /// (<col_name> <col_type>, ...)
  columns : Array[ColumnDef]
  /// PRIMARY KEY <key>
  primary_key : String?
} derive(Eq)

///|
impl @pp.Pretty for CreateTableStmt with pretty(self) {
  @pp.text("CREATE TABLE ") +
  @pp.text(self.name) +
  @pp.text(" (") +
  @pp.nest(
    @pp.hardline +
    @pp.separate(@pp.text(", ") + @pp.hardline, self.columns.map(@pp.pretty)),
  ) +
  @pp.hardline +
  @pp.text(")")
}

///|
pub struct ColumnDef {
  name : String
  data_type : DataType
  options : Array[ColumnDefOption]
} derive(Eq)

///|
impl @pp.Pretty for ColumnDef with pretty(self) {
  @pp.text(self.name) +
  @pp.space +
  self.data_type.pretty() +
  @pp.separate(@pp.empty, self.options.map(@pp.pretty))
}

///|
pub enum DataType {
  Integer
  Float(Int?)
  Real
  Double
  Char(Int)
  Varchar(Int)
  Text
  Boolean
  Timestamp
  Blob
  // Interval
} derive(Eq)

///|
impl @pp.Pretty for DataType with pretty(self) {
  match self {
    Integer => @pp.text("INTEGER")
    Float(Some(p)) => @pp.text("FLOAT(\{p})")
    Float(None) => @pp.text("FLOAT")
    Real => @pp.text("REAL")
    Double => @pp.text("DOUBLE")
    Char(size) => @pp.text("CHAR(\{size})")
    Varchar(size) => @pp.text("VARCHAR(\{size})")
    Text => @pp.text("TEXT")
    Boolean => @pp.text("BOOLEAN")
    Timestamp => @pp.text("TIMESTAMP")
    Blob => @pp.text("BLOB")
  }
}

///|
pub enum ColumnDefOption {
  NotNull
  Unique
  Default(Expr)
} derive(Eq)

///|
impl @pp.Pretty for ColumnDefOption with pretty(self) {
  match self {
    NotNull => @pp.text(" NOT NULL")
    Unique => @pp.text(" UNIQUE")
    Default(expr) => @pp.text(" DEFAULT ") + expr.pretty()
  }
}

///|
struct CreateViewStmt {
  /// CREATE VIEW <view_name>
  name : String
  /// [(<column_name>, ...)]
  columns : Array[ViewColumnDef]
  /// AS <select_stmt>
  query : SelectStmt
} derive(Eq)

///|
impl @pp.Pretty for CreateViewStmt with pretty(self) {
  @pp.text("CREATE VIEW ") +
  @pp.text(self.name) +
  (if self.columns.length() > 0 {
    @pp.text(" (") +
    @pp.separate(@pp.text(", "), self.columns.map(@pp.pretty)) +
    @pp.char(')')
  } else {
    @pp.empty
  }) +
  @pp.space +
  @pp.text("AS") +
  @pp.hardline +
  self.query.pretty()
}

///|
pub struct ViewColumnDef {
  name : String
} derive(Eq)

///|
impl @pp.Pretty for ViewColumnDef with pretty(self) {
  @pp.text(self.name)
}

///|
pub struct DropViewStmt {
  /// DROP VIEW <view_name>
  name : String
} derive(Eq)

///|
impl @pp.Pretty for DropViewStmt with pretty(self) {
  @pp.text("DROP VIEW ") + @pp.text(self.name)
}

///|
pub enum DuplicateTreatment {
  /// DISTINCT
  Distinct
  /// ALL
  All
} derive(Eq)

///|
impl @pp.Pretty for DuplicateTreatment with pretty(self) {
  match self {
    DuplicateTreatment::Distinct => @pp.text("DISTINCT")
    DuplicateTreatment::All => @pp.text("ALL")
  }
}
