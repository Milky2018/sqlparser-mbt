///|
pub fn[T : @pp.Pretty] pretty_print(obj : T) -> String {
  @pp.pretty(obj).to_string()
}

///|
pub fn[T : Show] structural_print(obj : T) -> String {
  obj.to_string()
}

///|
pub struct Statements {
  /// The list of SQL statements parsed from the input.
  stmts : Array[Statement]
} derive(Eq, Show)

///|
pub impl @pp.Pretty for Statements with pretty(self) {
  @pp.separate(@pp.hardline + @pp.hardline, self.stmts.map(@pp.pretty))
}

///|
pub fn Statements::op_get(self : Self, index : Int) -> Statement {
  self.stmts[index]
}

///|
pub enum Statement {
  Query(QueryStmt)
  CreateTable(CreateTableStmt)
  CreateView(CreateViewStmt)
  DropView(DropViewStmt)
  DropTable(DropTableStmt)
  Insert(InsertStmt)
  Delete(DeleteStmt)
  Update(UpdateStmt)
  Truncate(TruncateStmt)
  AlterTable(AlterTableStmt)
  Show(ShowStmt)
} derive(Eq, Show)

///|
pub impl @pp.Pretty for Statement with pretty(self) {
  (match self {
    Statement::Query(stmt) => stmt.pretty()
    CreateTable(stmt) => stmt.pretty()
    CreateView(stmt) => stmt.pretty()
    DropView(stmt) => stmt.pretty()
    DropTable(stmt) => stmt.pretty()
    Insert(stmt) => stmt.pretty()
    Delete(stmt) => stmt.pretty()
    Update(stmt) => stmt.pretty()
    Truncate(stmt) => stmt.pretty()
    AlterTable(stmt) => stmt.pretty()
    Show(stmt) => stmt.pretty()
  }) +
  @pp.text(";")
}

///|
pub struct QueryStmt {
  /// SELECT ...
  body : SetExpr
  /// ORDER BY <order_by>
  order_by : Array[OrderByExpr]
  /// LIMIT <expr>
  limit : Expr?
  /// OFFSET <expr>
  offset : Expr?
} derive(Eq, Show)

///|
pub impl @pp.Pretty for QueryStmt with pretty(self) {
  self.body.pretty() +
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
enum SetExpr {
  /// Restricted
  Select(SelectStmt)
  /// Parenthesized
  Query(QueryStmt)
  /// UNION, INTERSECT, EXCEPT
  SetOperation(SetOperator, SetExpr, SetExpr)
} derive(Eq, Show)

///|
impl @pp.Pretty for SetExpr with pretty(self) {
  match self {
    Select(stmt) => stmt.pretty()
    Query(stmt) =>
      @pp.parens(@pp.nest(@pp.hardline + stmt.pretty()) + @pp.hardline)
    SetOperation(op, left, right) =>
      left.pretty() + @pp.hardline + op.pretty() + @pp.hardline + right.pretty()
  }
}

///|
struct SelectStmt {
  /// SELECT <projections>
  projections : Array[Projection]
  /// TOP <expr>
  top : Top?
  /// (DISTINCT <projections>)
  distinct : Bool
  /// FROM <table_refs>
  from : Array[TableRef]
  /// WHERE <where_clause>
  where_clause : Expr?
  /// GROUP BY <group_by>
  group_by : Array[Expr]
  /// HAVING <expr>
  having : Expr?
} derive(Eq, Show)

///|
pub impl @pp.Pretty for SelectStmt with pretty(self) {
  @pp.text("SELECT") +
  (if self.top is Some(top) { top.pretty() } else { @pp.empty }) +
  (if self.distinct { @pp.text(" DISTINCT") } else { @pp.empty }) +
  (if self.projections.length() == 0 {
    @pp.nest(@pp.hardline + @pp.text("*"))
  } else {
    @pp.nest(
      @pp.hardline +
      @pp.separate(
        @pp.char(',') + @pp.hardline,
        self.projections.map(@pp.pretty),
      ),
    )
  }) +
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
  })
}

///|
enum SetOperator {
  Union
  Intersect
  Except
} derive(Eq, Show)

///|
pub impl @pp.Pretty for SetOperator with pretty(self) {
  match self {
    SetOperator::Union => @pp.text("UNION")
    SetOperator::Intersect => @pp.text("INTERSECT")
    SetOperator::Except => @pp.text("EXCEPT")
  }
}

///|
pub enum Projection {
  Wildcard
  UnamedExpr(Expr)
  AliasedExpr(Expr, String)
} derive(Eq, Show)

///|
pub impl @pp.Pretty for Projection with pretty(self) {
  match self {
    Projection::Wildcard => @pp.char('*')
    Projection::UnamedExpr(expr) => expr.pretty()
    Projection::AliasedExpr(expr, alias_name) =>
      expr.pretty() + @pp.text(" AS ") + @pp.text(alias_name)
  }
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
  SubQuery(QueryStmt)
  /// [NOT] EXISTS
  Exists(positive~ : Bool, QueryStmt)
  /// <expr> [NOT] BETWEEN <expr> AND <expr>
  Between(positive~ : Bool, Expr, Expr, Expr)
  /// EXTRACT(YEAR FROM <expr>)
  Extract(PrimaryDatetimeField, Expr)
  /// CASE [operand] WHEN <expr> THEN <expr> [...] [ELSE <expr>] END
  Case(CaseExpr)
  /// <expr> [NOT] IN (<expr>, ...)
  InList(positive~ : Bool, Expr, Array[Expr])
  /// <expr> [NOT] IN (SELECT ...)
  InSubQuery(positive~ : Bool, Expr, QueryStmt)
  /// ```sql
  /// SUBSTRING(<expr> [FROM <expr>] [FOR <expr>])
  /// ```
  /// or
  /// ```sql
  /// SUBSTRING(<expr>, <expr>, <expr>)
  /// ```
  Substring(Expr, Expr?, Expr?)
  /// ?
  PlaceHolder
} derive(Eq, Show)

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
pub impl @pp.Pretty for Expr with pretty(self) {
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
    Expr::Substring(expr, from, for_expr) =>
      @pp.text("SUBSTRING(") +
      expr.pretty() +
      (match from {
        Some(from_expr) => @pp.text(" FROM ") + from_expr.pretty()
        None => @pp.empty
      }) +
      (match for_expr {
        Some(for_expr) => @pp.text(" FOR ") + for_expr.pretty()
        None => @pp.empty
      }) +
      @pp.char(')')
    Expr::PlaceHolder => @pp.text("?")
  }
}

///|
pub enum Literal {
  Integer(Int)
  Double(Double) // TODO: float32
  String(String)
  Boolean(Bool)
  Null
} derive(Eq, Show)

///|
pub impl @pp.Pretty for Literal with pretty(self) {
  match self {
    Literal::Integer(value) => @pp.text("\{value}")
    Literal::Double(value) => @pp.text("\{value}")
    Literal::String(value) => @pp.text("'\{value}'")
    Literal::Boolean(value) => @pp.text(if value { "TRUE" } else { "FALSE" })
    Literal::Null => @pp.text("NULL")
  }
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
} derive(Eq, Show)

///|
pub impl @pp.Pretty for BinaryOperator with pretty(self) {
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
pub enum UnaryOperator {
  Plus
  Minus
  Not
} derive(Eq, Show)

///|
pub impl @pp.Pretty for UnaryOperator with pretty(self) {
  match self {
    UnaryOperator::Plus => @pp.text("+")
    UnaryOperator::Minus => @pp.text("-")
    UnaryOperator::Not => @pp.text("NOT ")
  }
}

///|
pub struct OrderByExpr {
  /// ORDER BY <expr>
  expr : Expr
  /// ASC | DESC
  asc : Bool?
  /// NULLS FIRST | NULLS LAST
  nulls_first : Bool?
} derive(Eq, Show)

///|
pub impl @pp.Pretty for OrderByExpr with pretty(self) {
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
pub struct TableRef {
  factor : TableFactor
  joins : Array[Join]
} derive(Eq, Show)

///|
pub impl @pp.Pretty for TableRef with pretty(self) {
  self.factor.pretty() +
  @pp.separate_map(@pp.hardline, self.joins, fn(join) { join.pretty() })
}

///|
pub enum TableFactor {
  /// <col_name> [AS <alias>]
  Column(ObjectName, TableAlias?)
  /// FROM (SELECT ...) [AS <alias>]
  SubQuery(QueryStmt, TableAlias?)
} derive(Eq, Show)

///|
pub impl @pp.Pretty for TableFactor with pretty(self) {
  match self {
    TableFactor::Column(name, alias_name) =>
      name.pretty() +
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
pub struct TableAlias {
  /// AS <alias>
  name : String
  /// AS <alias> (<col_name>, ...)
  columns : Array[String]
} derive(Eq, Show)

///|
pub impl @pp.Pretty for TableAlias with pretty(self) {
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
pub struct Join {
  /// JOIN <table_ref> ON <expr>
  table_ref : TableRef
  /// LEFT JOIN | RIGHT JOIN | FULL | INNER | CROSS
  join_operator : JoinOperator
} derive(Eq, Show)

///|
pub impl @pp.Pretty for Join with pretty(self) {
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
} derive(Eq, Show)

///|
pub impl @pp.Pretty for JoinOperator with pretty(self) {
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
pub enum JoinConstraint {
  /// ON <expr>
  On(Expr)
  /// USING (<col_name>, ...)
  Using(Array[String])
  None
} derive(Eq, Show)

///|
pub impl @pp.Pretty for JoinConstraint with pretty(self) {
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
pub enum IntervalQualifier {
  /// YEAR, MONTH, DAY, HOUR, MINUTE, SECOND
  Single(PrimaryDatetimeField)
  /// <from> TO <to>
  Range(PrimaryDatetimeField, PrimaryDatetimeField)
} derive(Eq, Show)

///|
pub impl @pp.Pretty for IntervalQualifier with pretty(self) {
  match self {
    IntervalQualifier::Single(field) => field.pretty()
    IntervalQualifier::Range(from, to) =>
      @pp.group(from.pretty() + @pp.text(" TO ") + to.pretty())
  }
}

///|
struct PrimaryDatetimeField {
  /// YEAR, MONTH, DAY, HOUR, MINUTE, SECOND
  field : DatetimeUnit
  /// (3)
  precision : Int?
} derive(Eq, Show)

///|
pub impl @pp.Pretty for PrimaryDatetimeField with pretty(self) {
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
pub enum DatetimeUnit {
  Year
  Month
  Day
  Hour
  Minute
  Second
} derive(Eq, Show)

///|
pub impl @pp.Pretty for DatetimeUnit with pretty(self) {
  match self {
    DatetimeUnit::Year => @pp.text("YEAR")
    DatetimeUnit::Month => @pp.text("MONTH")
    DatetimeUnit::Day => @pp.text("DAY")
    DatetimeUnit::Hour => @pp.text("HOUR")
    DatetimeUnit::Minute => @pp.text("MINUTE")
    DatetimeUnit::Second => @pp.text("SECOND")
  }
}

///| CASE [operand] WHEN <expr> THEN <expr> [...] [ELSE <expr>] END
pub struct CaseExpr {
  /// CASE [operand]
  operand : Expr?
  /// WHEN <expr> THEN <expr> [...]
  when_then_clauses : Array[(Expr, Expr)]
  /// ELSE <expr>
  else_expr : Expr?
} derive(Eq, Show)

///|
pub impl @pp.Pretty for CaseExpr with pretty(self) {
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
pub struct CreateTableStmt {
  /// CREATE TABLE <table_name>
  name : String
  /// IF NOT EXISTS flag
  if_not_exists : Bool
  /// Table definition - either column definitions or AS SELECT query
  definition : CreateTableDefinition
} derive(Eq, Show)

///|
pub enum CreateTableDefinition {
  /// (col_name col_type, ...)
  Columns(Array[ColumnDef], Array[TableConstraint])
  /// AS SELECT ...
  AsQuery(QueryStmt)
} derive(Eq, Show)

///|
pub impl @pp.Pretty for CreateTableStmt with pretty(self) {
  @pp.text("CREATE TABLE ") +
  (if self.if_not_exists {
    @pp.text("IF NOT EXISTS ")
  } else {
    @pp.empty
  }) +
  @pp.text(self.name) +
  @pp.space +
  self.definition.pretty()
}

///|
pub impl @pp.Pretty for CreateTableDefinition with pretty(self) {
  match self {
    CreateTableDefinition::Columns(columns, constraints) =>
      @pp.text("(") +
      @pp.nest(
        @pp.hardline +
        @pp.separate(@pp.text(", ") + @pp.hardline, columns.map(@pp.pretty)) +
        (if constraints.length() == 0 {
          @pp.empty
        } else {
          @pp.text(", ") +
          @pp.hardline +
          @pp.separate(
            @pp.text(", ") + @pp.hardline,
            constraints.map(@pp.pretty),
          )
        }),
      ) +
      @pp.hardline +
      @pp.text(")")
    CreateTableDefinition::AsQuery(query) =>
      @pp.text("AS ") + query.pretty()
  }
}

///|
pub struct ColumnDef {
  name : String
  data_type : DataType
  options : Array[ColumnDefOption]
} derive(Eq, Show)

///|
pub impl @pp.Pretty for ColumnDef with pretty(self) {
  @pp.text(self.name) +
  @pp.space +
  self.data_type.pretty() +
  @pp.separate(@pp.empty, self.options.map(@pp.pretty))
}

///|
pub enum DataType {
  Integer
  Smallint
  Bigint
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
} derive(Eq, Show)

///|
pub impl @pp.Pretty for DataType with pretty(self) {
  match self {
    Integer => @pp.text("INTEGER")
    Smallint => @pp.text("SMALLINT")
    Bigint => @pp.text("BIGINT")
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
  PrimaryKey
} derive(Eq, Show)

///|
pub impl @pp.Pretty for ColumnDefOption with pretty(self) {
  match self {
    NotNull => @pp.text(" NOT NULL")
    Unique => @pp.text(" UNIQUE")
    Default(expr) => @pp.text(" DEFAULT ") + expr.pretty()
    PrimaryKey => @pp.text(" PRIMARY KEY")
  }
}

///|
struct CreateViewStmt {
  /// CREATE VIEW <view_name>
  name : String
  /// [(<column_name>, ...)]
  columns : Array[ViewColumnDef]
  /// AS <select_stmt>
  query : QueryStmt
} derive(Eq, Show)

///|
pub impl @pp.Pretty for CreateViewStmt with pretty(self) {
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
} derive(Eq, Show)

///|
pub impl @pp.Pretty for ViewColumnDef with pretty(self) {
  @pp.text(self.name)
}

///|
pub struct DropViewStmt {
  /// DROP VIEW <view_name>
  name : String
} derive(Eq, Show)

///|
pub impl @pp.Pretty for DropViewStmt with pretty(self) {
  @pp.text("DROP VIEW ") + @pp.text(self.name)
}

///|
pub enum DuplicateTreatment {
  /// DISTINCT
  Distinct
  /// ALL
  All
} derive(Eq, Show)

///|
pub impl @pp.Pretty for DuplicateTreatment with pretty(self) {
  match self {
    DuplicateTreatment::Distinct => @pp.text("DISTINCT")
    DuplicateTreatment::All => @pp.text("ALL")
  }
}

///|
pub enum TableConstraint {
  Unique(Array[OrderByExpr])
  PrimaryKey(Array[OrderByExpr])
  ForeignKey(
    columns~ : Array[OrderByExpr],
    foreign_table~ : ObjectName,
    foreign_columns~ : Array[String]
  )
  Check(Expr)
} derive(Eq, Show)

///|
pub impl @pp.Pretty for TableConstraint with pretty(self) {
  match self {
    Unique(cols) =>
      @pp.text("UNIQUE ") +
      @pp.parens(@pp.separate(@pp.text(", "), cols.map(@pp.pretty)))
    PrimaryKey(cols) =>
      @pp.text("PRIMARY KEY ") +
      @pp.parens(@pp.separate(@pp.text(", "), cols.map(@pp.pretty)))
    ForeignKey(columns~, foreign_table~, foreign_columns~) =>
      @pp.text("FOREIGN KEY ") +
      @pp.parens(@pp.separate(@pp.text(", "), columns.map(@pp.pretty))) +
      @pp.text(" REFERENCES ") +
      foreign_table.pretty() +
      (if foreign_columns.length() == 0 {
        @pp.empty
      } else {
        @pp.space +
        @pp.parens(@pp.separate(@pp.text(", "), foreign_columns.map(@pp.text)))
      })
    Check(expr) => @pp.text("CHECK (") + expr.pretty() + @pp.char(')')
  }
}

///|
pub struct ObjectName {
  /// <identifier>.<identifier>.<identifier>
  parts : Array[String]
} derive(Eq, Show)

///|
pub impl @pp.Pretty for ObjectName with pretty(self) {
  @pp.separate(@pp.text("."), self.parts.map(@pp.text))
}

///|
pub enum Top {
  Constant(Int)
  Expr(Expr)
} derive(Eq, Show)

///|
pub impl @pp.Pretty for Top with pretty(self) {
  match self {
    Top::Constant(value) => @pp.text(" TOP \{value}")
    Top::Expr(expr) => @pp.text(" TOP (") + expr.pretty() + @pp.text(")")
  }
}

///|
pub struct InsertStmt {
  /// INSERT INTO <table_name>
  table_name : ObjectName
  /// Optional column list: (<col1>, <col2>, ...)
  columns : Array[String]
  /// The inserted data source
  source : InsertSource
} derive(Eq, Show)

///|
pub impl @pp.Pretty for InsertStmt with pretty(self) {
  @pp.text("INSERT INTO ") +
  self.table_name.pretty() +
  (if self.columns.length() > 0 {
    @pp.space +
    @pp.parens(@pp.separate(@pp.text(", "), self.columns.map(@pp.text)))
  } else {
    @pp.empty
  }) +
  @pp.space +
  self.source.pretty()
}

///|
pub enum InsertSource {
  /// VALUES (<expr>, ...), (<expr>, ...), ...
  Values(Array[Array[Expr]])
  /// SELECT ...
  Query(QueryStmt)
} derive(Eq, Show)

///|
pub impl @pp.Pretty for InsertSource with pretty(self) {
  match self {
    InsertSource::Values(rows) =>
      @pp.text("VALUES ") +
      @pp.separate(
        @pp.text(", "),
        rows.map(fn(row) {
          @pp.parens(@pp.separate(@pp.text(", "), row.map(@pp.pretty)))
        })
      )
    InsertSource::Query(query) => query.pretty()
  }
}

///|
pub struct DeleteStmt {
  /// DELETE FROM <table_name>
  table_name : ObjectName
  /// Optional WHERE clause
  where_clause : Option[Expr]
} derive(Eq, Show)

///|
pub impl @pp.Pretty for DeleteStmt with pretty(self) {
  @pp.text("DELETE FROM ") +
  self.table_name.pretty() +
  (match self.where_clause {
    Some(expr) => @pp.hardline + @pp.text("WHERE") + @pp.space + expr.pretty()
    None => @pp.empty
  })
}

///|
pub struct UpdateStmt {
  /// UPDATE <table_name>
  table_name : ObjectName
  /// SET assignments
  assignments : Array[Assignment]
  /// Optional WHERE clause
  where_clause : Option[Expr]
} derive(Eq, Show)

///|
pub struct Assignment {
  /// Column name
  column : String
  /// Value expression
  value : Expr
} derive(Eq, Show)

///|
pub impl @pp.Pretty for UpdateStmt with pretty(self) {
  @pp.text("UPDATE ") +
  self.table_name.pretty() +
  @pp.hardline +
  @pp.text("SET ") +
  @pp.separate(@pp.text(", "), self.assignments.map(@pp.pretty)) +
  (match self.where_clause {
    Some(expr) => @pp.hardline + @pp.text("WHERE") + @pp.space + expr.pretty()
    None => @pp.empty
  })
}

///|
pub impl @pp.Pretty for Assignment with pretty(self) {
  @pp.text(self.column) + @pp.text(" = ") + self.value.pretty()
}

///|
pub struct TruncateStmt {
  /// TRUNCATE <table_name>
  table_name : ObjectName
} derive(Eq, Show)

///|
pub impl @pp.Pretty for TruncateStmt with pretty(self) {
  @pp.text("TRUNCATE ") + self.table_name.pretty()
}

///|
pub struct DropTableStmt {
  /// DROP TABLE <table_name>
  table_name : ObjectName
  /// IF EXISTS flag
  if_exists : Bool
} derive(Eq, Show)

///|
pub impl @pp.Pretty for DropTableStmt with pretty(self) {
  @pp.text("DROP TABLE ") +
  (if self.if_exists {
    @pp.text("IF EXISTS ")
  } else {
    @pp.empty
  }) +
  self.table_name.pretty()
}

///|
pub struct AlterTableStmt {
  /// ALTER TABLE <table_name>
  table_name : ObjectName
  /// IF EXISTS flag
  if_exists : Bool
  /// Table alteration operation
  operation : AlterTableOperation
} derive(Eq, Show)

///|
pub enum AlterTableOperation {
  /// DROP COLUMN [IF EXISTS] <column_name>
  DropColumn(String, Bool) // column_name, if_exists
} derive(Eq, Show)

///|
pub impl @pp.Pretty for AlterTableStmt with pretty(self) {
  @pp.text("ALTER TABLE ") +
  (if self.if_exists {
    @pp.text("IF EXISTS ")
  } else {
    @pp.empty
  }) +
  self.table_name.pretty() +
  @pp.space +
  self.operation.pretty()
}

///|
pub impl @pp.Pretty for AlterTableOperation with pretty(self) {
  match self {
    AlterTableOperation::DropColumn(column_name, if_exists) =>
      @pp.text("DROP COLUMN ") +
      (if if_exists {
        @pp.text("IF EXISTS ")
      } else {
        @pp.empty
      }) +
      @pp.text(column_name)
  }
}

///|
/// MySQL SHOW statement
pub struct ShowStmt {
  /// The type of SHOW statement
  show_type : ShowType
  /// Optional object name (table, database, etc.)
  object : Option[ObjectName]
  /// Optional filter condition
  filter : Option[ShowFilter]
} derive(Eq, Show)

///|
pub enum ShowType {
  Tables
  Columns
  Status
  Databases
} derive(Eq, Show)

///|
pub enum ShowFilter {
  Like(String)
  Where(Expr)
} derive(Eq, Show)

///|
pub impl @pp.Pretty for ShowStmt with pretty(self) {
  @pp.text("SHOW ") +
  self.show_type.pretty() +
  (match self.object {
    Some(obj) => @pp.space + @pp.text("FROM ") + obj.pretty()
    None => @pp.empty
  }) +
  (match self.filter {
    Some(filter) => @pp.space + filter.pretty()
    None => @pp.empty
  })
}

///|
pub impl @pp.Pretty for ShowType with pretty(self) {
  match self {
    ShowType::Tables => @pp.text("TABLES")
    ShowType::Columns => @pp.text("COLUMNS")
    ShowType::Status => @pp.text("STATUS")
    ShowType::Databases => @pp.text("DATABASES")
  }
}

///|
pub impl @pp.Pretty for ShowFilter with pretty(self) {
  match self {
    ShowFilter::Like(pattern) => @pp.text("LIKE '") + @pp.text(pattern) + @pp.text("'")
    ShowFilter::Where(expr) => @pp.text("WHERE ") + expr.pretty()
  }
}
