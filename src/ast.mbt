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
  CreateIndex(CreateIndexStmt)
  CreateDatabase(CreateDatabaseStmt)
  CreateSchema(CreateSchemaStmt)
  CreateFunction(CreateFunctionStmt)
  CreateProcedure(CreateProcedureStmt)
  CreateSequence(CreateSequenceStmt)
  DropView(DropViewStmt)
  DropTable(DropTableStmt)
  DropIndex(DropIndexStmt)
  Insert(InsertStmt)
  Delete(DeleteStmt)
  Update(UpdateStmt)
  Merge(MergeStmt)
  Truncate(TruncateStmt)
  AlterTable(AlterTableStmt)
  AlterIndex(AlterIndexStmt)
  Show(ShowStmt)
  Set(SetStmt)
  LockTables(Array[ObjectName])
  UnlockTables
  // PostgreSQL-specific statements
  Listen(String)
  Notify(String, String?)
  // TCL (Transaction Control Language) statements
  Begin(BeginStmt)
  Commit(CommitStmt)
  Rollback(RollbackStmt)
  Savepoint(SavepointStmt)
  ReleaseSavepoint(ReleaseSavepointStmt)
  // DCL (Data Control Language) statements
  Grant(GrantStmt)
  Revoke(RevokeStmt)
} derive(Eq, Show)

///|
pub impl @pp.Pretty for Statement with pretty(self) {
  (match self {
    Statement::Query(stmt) => stmt.pretty()
    CreateTable(stmt) => stmt.pretty()
    CreateView(stmt) => stmt.pretty()
    CreateIndex(stmt) => stmt.pretty()
    CreateDatabase(stmt) => stmt.pretty()
    CreateSchema(stmt) => stmt.pretty()
    CreateFunction(stmt) => stmt.pretty()
    CreateProcedure(stmt) => stmt.pretty()
    CreateSequence(stmt) => stmt.pretty()
    DropView(stmt) => stmt.pretty()
    DropTable(stmt) => stmt.pretty()
    DropIndex(stmt) => stmt.pretty()
    Insert(stmt) => stmt.pretty()
    Delete(stmt) => stmt.pretty()
    Update(stmt) => stmt.pretty()
    Merge(stmt) => stmt.pretty()
    Truncate(stmt) => stmt.pretty()
    AlterTable(stmt) => stmt.pretty()
    AlterIndex(stmt) => stmt.pretty()
    Show(stmt) => stmt.pretty()
    Set(stmt) => stmt.pretty()
    LockTables(tables) => @pp.text("LOCK TABLES ") + @pp.separate(@pp.text(", "), tables.map(@pp.pretty))
    UnlockTables => @pp.text("UNLOCK TABLES")
    Listen(channel) => @pp.text("LISTEN ") + @pp.text(channel)
    Notify(channel, payload) => @pp.text("NOTIFY ") + @pp.text(channel) + 
      (match payload {
        Some(msg) => @pp.text(", '") + @pp.text(msg) + @pp.text("'")
        None => @pp.empty
      })
    Begin(stmt) => stmt.pretty()
    Commit(stmt) => stmt.pretty()
    Rollback(stmt) => stmt.pretty()
    Savepoint(stmt) => stmt.pretty()
    ReleaseSavepoint(stmt) => stmt.pretty()
    Grant(stmt) => stmt.pretty()
    Revoke(stmt) => stmt.pretty()
  }) +
  @pp.text(";")
}

///|
pub struct QueryStmt {
  // WITH <cte1> AS (...), <cte2> AS (...)
  with_clause : Array[Cte]?
  // SELECT ...
  body : SetExpr
  // ORDER BY <order_by>
  order_by : Array[OrderByExpr]
  // LIMIT <expr>
  limit : Expr?
  // OFFSET <expr>
  offset : Expr?
} derive(Eq, Show)

///|
pub impl @pp.Pretty for QueryStmt with pretty(self) {
  (match self.with_clause {
    Some(ctes) => 
      @pp.text("WITH ") +
      @pp.separate(@pp.text(", ") + @pp.hardline, ctes.map(@pp.pretty)) +
      @pp.hardline
    None => @pp.empty
  }) +
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
  // Restricted
  Select(SelectStmt)
  // Parenthesized
  Query(QueryStmt)
  // UNION, INTERSECT, EXCEPT
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
  // SELECT <projections>
  projections : Array[Projection]
  // TOP <expr>
  top : Top?
  // (DISTINCT <projections>)
  distinct : Bool
  // FROM <table_refs>
  from : Array[TableRef]
  // WHERE <where_clause>
  where_clause : Expr?
  // GROUP BY <group_by>
  group_by : Array[Expr]
  // HAVING <expr>
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
  // sum(*) [FILTER (WHERE condition)]
  FunctionCall(String, DuplicateTreatment?, Array[Expr], Expr?)
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
  SubQuery(QueryStmt)
  // [NOT] EXISTS
  Exists(positive~ : Bool, QueryStmt)
  // <expr> [NOT] BETWEEN <expr> AND <expr>
  Between(positive~ : Bool, Expr, Expr, Expr)
  // EXTRACT(YEAR FROM <expr>)
  Extract(PrimaryDatetimeField, Expr)
  // CASE [operand] WHEN <expr> THEN <expr> [...] [ELSE <expr>] END
  Case(CaseExpr)
  // <expr> [NOT] IN (<expr>, ...)
  InList(positive~ : Bool, Expr, Array[Expr])
  // <expr> [NOT] IN (SELECT ...)
  InSubQuery(positive~ : Bool, Expr, QueryStmt)
  // ```sql
  // SUBSTRING(<expr> [FROM <expr>] [FOR <expr>])
  // ```
  // or
  // ```sql
  // SUBSTRING(<expr>, <expr>, <expr>)
  // ```
  Substring(Expr, Expr?, Expr?)
  // ?
  PlaceHolder
  // @param_name (BigQuery named parameter)
  NamedParameter(String)
  // Array expression: ARRAY[1, 2, 3] or [1, 2, 3]
  Array(ArrayExpr)
  // Array/Map indexing and slicing: arr[1], arr[1:3], obj.field
  CompoundFieldAccess(Expr, Array[AccessExpr])
  // Window function: func() OVER (PARTITION BY ... ORDER BY ... ROWS/RANGE ...)
  WindowFunction(String, DuplicateTreatment?, Array[Expr], WindowSpec)
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
    Expr::FunctionCall(name, dup, args, filter) =>
      @pp.text(name) +
      @pp.parens(
        (if dup is Some(dup) { dup.pretty() + @pp.space } else { @pp.empty }) +
        @pp.separate(@pp.text(", "), args.map(@pp.pretty)),
      ) +
      (if filter is Some(filter) { 
        @pp.text(" FILTER (WHERE ") + filter.pretty() + @pp.text(")")
      } else { 
        @pp.empty 
      })
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
    Expr::NamedParameter(name) => @pp.text("@") + @pp.text(name)
    Expr::Array(arr) => arr.pretty()
    Expr::CompoundFieldAccess(root, access_chain) =>
      root.pretty() + @pp.separate(@pp.empty, access_chain.map(@pp.pretty))
    Expr::WindowFunction(name, dup, args, window_spec) =>
      @pp.text(name) +
      @pp.parens(
        (if dup is Some(dup) { dup.pretty() + @pp.space } else { @pp.empty }) +
        @pp.separate(@pp.text(", "), args.map(@pp.pretty)),
      ) +
      @pp.text(" OVER (") +
      window_spec.pretty() +
      @pp.text(")")
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
/// PostgreSQL array expression
pub struct ArrayExpr {
  elem : Array[Expr]  // The list of expressions between brackets
  named : Bool        // true for ARRAY[..], false for [..]
} derive(Eq, Show)

///|
pub impl @pp.Pretty for ArrayExpr with pretty(self) {
  (if self.named { @pp.text("ARRAY") } else { @pp.empty }) +
  @pp.text("[") +
  @pp.separate(@pp.text(", "), self.elem.map(@pp.pretty)) +
  @pp.text("]")
}

///|
/// Access expression for array indexing, slicing, and field access
pub enum AccessExpr {
  Dot(Expr)           // Field access: obj.field
  Subscript(Subscript) // Array/map subscript: arr[index] or arr[start:end]
} derive(Eq, Show)

///|
pub impl @pp.Pretty for AccessExpr with pretty(self) {
  match self {
    AccessExpr::Dot(expr) => @pp.text(".") + expr.pretty()
    AccessExpr::Subscript(subscript) => subscript.pretty()
  }
}

///|
/// Subscript expression for array indexing and slicing
pub enum Subscript {
  Index(Expr)         // Simple index: arr[1]
  Slice(Expr?, Expr?, Expr?) // Array slice: arr[1:3] (lower, upper, stride)
} derive(Eq, Show)

///|
pub impl @pp.Pretty for Subscript with pretty(self) {
  match self {
    Subscript::Index(index) => @pp.text("[") + index.pretty() + @pp.text("]")
    Subscript::Slice(lower, upper, stride) => {
      @pp.text("[") +
      (match lower { Some(l) => l.pretty(); None => @pp.empty }) +
      @pp.text(":") +
      (match upper { Some(u) => u.pretty(); None => @pp.empty }) +
      (match stride { Some(s) => @pp.text(":") + s.pretty(); None => @pp.empty }) +
      @pp.text("]")
    }
  }
}

///|
/// Common Table Expression (CTE) for WITH clauses
pub struct Cte {
  name : String          // CTE name
  query : QueryStmt       // CTE query body
  columns : Array[String]?  // Optional column list: WITH cte(col1, col2) AS (...)
} derive(Eq, Show)

///|
pub impl @pp.Pretty for Cte with pretty(self) {
  @pp.text(self.name) +
  (match self.columns {
    Some(cols) => 
      @pp.text("(") + 
      @pp.separate(@pp.text(", "), cols.map(@pp.text)) +
      @pp.text(")")
    None => @pp.empty
  }) +
  @pp.text(" AS (") +
  @pp.nest(@pp.hardline + self.query.pretty()) +
  @pp.hardline +
  @pp.text(")")
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
  IntegerDiv  // MySQL DIV keyword for integer division
  Mod
  And
  Or
  // PostgreSQL JSON operators
  JsonExtract        // ->
  JsonExtractText    // ->>
  JsonExtractPath    // #>
  JsonExtractPathText // #>>
  JsonContains       // @>
  JsonContainedIn    // <@
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
    BinaryOperator::IntegerDiv => @pp.text(" DIV ")
    BinaryOperator::Mod => @pp.text("%")
    BinaryOperator::And => @pp.hardline + @pp.text("AND")
    BinaryOperator::Or => @pp.hardline + @pp.text("OR")
    // PostgreSQL JSON operators
    BinaryOperator::JsonExtract => @pp.text("->")
    BinaryOperator::JsonExtractText => @pp.text("->>")
    BinaryOperator::JsonExtractPath => @pp.text("#>")
    BinaryOperator::JsonExtractPathText => @pp.text("#>>")
    BinaryOperator::JsonContains => @pp.text("@>")
    BinaryOperator::JsonContainedIn => @pp.text("<@")
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
  // ORDER BY <expr>
  expr : Expr
  // ASC | DESC
  asc : Bool?
  // NULLS FIRST | NULLS LAST
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
  // <col_name> [AS <alias>]
  Column(ObjectName, TableAlias?)
  // FROM (SELECT ...) [AS <alias>]
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
  // JOIN <table_ref> ON <expr>
  table_ref : TableRef
  // LEFT JOIN | RIGHT JOIN | FULL | INNER | CROSS
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
  // ON <expr>
  On(Expr)
  // USING (<col_name>, ...)
  Using(Array[String])
  Non
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
    JoinConstraint::Non => @pp.empty
  }
}

///|
pub enum IntervalQualifier {
  // YEAR, MONTH, DAY, HOUR, MINUTE, SECOND
  Single(PrimaryDatetimeField)
  // <from> TO <to>
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
  // YEAR, MONTH, DAY, HOUR, MINUTE, SECOND
  field : DatetimeUnit
  // (3)
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
  // CASE [operand]
  operand : Expr?
  // WHEN <expr> THEN <expr> [...]
  when_then_clauses : Array[(Expr, Expr)]
  // ELSE <expr>
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

///| Window function specification: OVER ([PARTITION BY ...] [ORDER BY ...] [frame_clause])
pub struct WindowSpec {
  // PARTITION BY <expr>, ...
  partition_by : Array[Expr]
  // ORDER BY <expr> [ASC|DESC] [NULLS FIRST|LAST], ...
  order_by : Array[OrderByExpr]
  // frame clause: ROWS/RANGE BETWEEN ... AND ... or ROWS/RANGE ...
  frame_clause : WindowFrameClause?
} derive(Eq, Show)

///| Window frame clause
pub struct WindowFrameClause {
  // ROWS or RANGE
  frame_units : WindowFrameUnits
  // Frame bounds
  frame_start : WindowFrameBound
  frame_end : WindowFrameBound?
} derive(Eq, Show)

///| Window frame units
pub enum WindowFrameUnits {
  Rows
  Range
} derive(Eq, Show)

///| Window frame bound
pub enum WindowFrameBound {
  UnboundedPreceding
  UnboundedFollowing
  CurrentRow
  Preceding(Expr)
  Following(Expr)
} derive(Eq, Show)

///|
pub impl @pp.Pretty for WindowSpec with pretty(self) {
  let partition_clause = if self.partition_by.is_empty() {
    @pp.empty
  } else {
    @pp.text("PARTITION BY ") + @pp.separate(@pp.text(", "), self.partition_by.map(@pp.pretty))
  }
  
  let order_clause = if self.order_by.is_empty() {
    @pp.empty
  } else {
    @pp.text("ORDER BY ") + @pp.separate(@pp.text(", "), self.order_by.map(@pp.pretty))
  }
  
  let frame_clause = match self.frame_clause {
    Some(frame) => @pp.space + frame.pretty()
    None => @pp.empty
  }
  
  let clauses = []
  if !self.partition_by.is_empty() {
    clauses.push(partition_clause)
  }
  if !self.order_by.is_empty() {
    clauses.push(order_clause)
  }
  
  @pp.separate(@pp.space, clauses) + frame_clause
}

///|
pub impl @pp.Pretty for WindowFrameClause with pretty(self) {
  let units_text = match self.frame_units {
    WindowFrameUnits::Rows => "ROWS"
    WindowFrameUnits::Range => "RANGE"
  }
  
  match self.frame_end {
    Some(end_bound) => 
      @pp.text(units_text) + @pp.text(" BETWEEN ") + 
      self.frame_start.pretty() + @pp.text(" AND ") + end_bound.pretty()
    None =>
      @pp.text(units_text) + @pp.space + self.frame_start.pretty()
  }
}

///|
pub impl @pp.Pretty for WindowFrameBound with pretty(self) {
  match self {
    WindowFrameBound::UnboundedPreceding => @pp.text("UNBOUNDED PRECEDING")
    WindowFrameBound::UnboundedFollowing => @pp.text("UNBOUNDED FOLLOWING")
    WindowFrameBound::CurrentRow => @pp.text("CURRENT ROW")
    WindowFrameBound::Preceding(expr) => expr.pretty() + @pp.text(" PRECEDING")
    WindowFrameBound::Following(expr) => expr.pretty() + @pp.text(" FOLLOWING")
  }
}

///|
pub struct CreateTableStmt {
  // CREATE TABLE <table_name>
  name : String
  // IF NOT EXISTS flag
  if_not_exists : Bool
  // Table definition - either column definitions or AS SELECT query
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
  // CREATE VIEW <view_name>
  name : String
  // [(<column_name>, ...)]
  columns : Array[ViewColumnDef]
  // AS <select_stmt>
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

///| CREATE INDEX statement
pub struct CreateIndexStmt {
  // CREATE [UNIQUE] INDEX [CONCURRENTLY] [IF NOT EXISTS] <index_name>
  unique : Bool
  concurrently : Bool
  if_not_exists : Bool
  name : String
  // ON <table_name>
  table_name : ObjectName
  // [USING <method>] - e.g., BTREE, HASH, GIN, GIST
  index_method : IndexMethod?
  // (<column> [ASC|DESC] [NULLS FIRST|LAST], ...)
  columns : Array[IndexColumn]
  // [WHERE <predicate>] - partial index
  where_clause : Expr?
} derive(Eq, Show)

///| Index creation method
pub enum IndexMethod {
  Btree
  Hash
  Gin
  Gist
  Spgist
  Brin
} derive(Eq, Show)

///| Index column specification
pub struct IndexColumn {
  name : Expr // Can be column name or expression
  asc : Bool? // None = default, Some(true) = ASC, Some(false) = DESC
  nulls_first : Bool? // None = default, Some(true) = NULLS FIRST, Some(false) = NULLS LAST
} derive(Eq, Show)

///|
pub impl @pp.Pretty for CreateIndexStmt with pretty(self) {
  @pp.text("CREATE") +
  (if self.unique { @pp.text(" UNIQUE") } else { @pp.empty }) +
  @pp.text(" INDEX") +
  (if self.concurrently { @pp.text(" CONCURRENTLY") } else { @pp.empty }) +
  (if self.if_not_exists { @pp.text(" IF NOT EXISTS") } else { @pp.empty }) +
  @pp.text(" ") + @pp.text(self.name) +
  @pp.text(" ON ") + self.table_name.pretty() +
  (match self.index_method {
    Some(index_method) => @pp.text(" USING ") + index_method.pretty()
    None => @pp.empty
  }) +
  @pp.text(" (") +
  @pp.separate(@pp.text(", "), self.columns.map(@pp.pretty)) +
  @pp.text(")") +
  (match self.where_clause {
    Some(expr) => @pp.text(" WHERE ") + expr.pretty()
    None => @pp.empty
  })
}

///|
pub impl @pp.Pretty for IndexMethod with pretty(self) {
  match self {
    IndexMethod::Btree => @pp.text("BTREE")
    IndexMethod::Hash => @pp.text("HASH")
    IndexMethod::Gin => @pp.text("GIN")
    IndexMethod::Gist => @pp.text("GIST")
    IndexMethod::Spgist => @pp.text("SPGIST")
    IndexMethod::Brin => @pp.text("BRIN")
  }
}

///|
pub impl @pp.Pretty for IndexColumn with pretty(self) {
  self.name.pretty() +
  (match self.asc {
    Some(true) => @pp.text(" ASC")
    Some(false) => @pp.text(" DESC")
    None => @pp.empty
  }) +
  (match self.nulls_first {
    Some(true) => @pp.text(" NULLS FIRST")
    Some(false) => @pp.text(" NULLS LAST")
    None => @pp.empty
  })
}

///|
pub impl @pp.Pretty for ViewColumnDef with pretty(self) {
  @pp.text(self.name)
}

///|
/// CREATE DATABASE statement
pub struct CreateDatabaseStmt {
  /// CREATE DATABASE <database_name>
  name : String
  /// IF NOT EXISTS flag
  if_not_exists : Bool
  /// Optional character set specification
  character_set : String?
  /// Optional collation specification  
  collate : String?
} derive(Eq, Show)

///|
pub impl @pp.Pretty for CreateDatabaseStmt with pretty(self) {
  @pp.text("CREATE DATABASE ") +
  (if self.if_not_exists { @pp.text("IF NOT EXISTS ") } else { @pp.empty }) +
  @pp.text(self.name) +
  (match self.character_set {
    Some(charset) => @pp.text(" CHARACTER SET ") + @pp.text(charset)
    None => @pp.empty
  }) +
  (match self.collate {
    Some(collation) => @pp.text(" COLLATE ") + @pp.text(collation)
    None => @pp.empty
  })
}

///|
/// CREATE SCHEMA statement (synonym for CREATE DATABASE in many dialects)
pub struct CreateSchemaStmt {
  /// CREATE SCHEMA <schema_name>
  name : String
  /// IF NOT EXISTS flag
  if_not_exists : Bool
  /// Optional AUTHORIZATION user
  authorization : String?
} derive(Eq, Show)

///|
pub impl @pp.Pretty for CreateSchemaStmt with pretty(self) {
  @pp.text("CREATE SCHEMA ") +
  (if self.if_not_exists { @pp.text("IF NOT EXISTS ") } else { @pp.empty }) +
  @pp.text(self.name) +
  (match self.authorization {
    Some(user) => @pp.text(" AUTHORIZATION ") + @pp.text(user)
    None => @pp.empty
  })
}

///|
/// CREATE FUNCTION statement
pub struct CreateFunctionStmt {
  /// CREATE FUNCTION <function_name>
  name : String
  /// Function parameters: (param1 type1, param2 type2, ...)
  parameters : Array[FunctionParameter]
  /// RETURNS return_type
  return_type : DataType?
  /// Function body language (SQL, plpgsql, etc.)
  language : String?
  /// Function body/definition
  body : String?
  /// DETERMINISTIC flag
  deterministic : Bool
  /// IF NOT EXISTS flag
  if_not_exists : Bool
} derive(Eq, Show)

///|
/// Function parameter definition
pub struct FunctionParameter {
  /// Parameter name
  name : String
  /// Parameter data type
  param_type : DataType
  /// IN/OUT/INOUT mode (default IN)
  mode : ParameterMode?
} derive(Eq, Show)

///|
/// Parameter mode for functions/procedures
pub enum ParameterMode {
  In
  Out
  InOut
} derive(Eq, Show)

///|
/// CREATE PROCEDURE statement
pub struct CreateProcedureStmt {
  /// CREATE PROCEDURE <procedure_name>
  name : String
  /// Procedure parameters: (param1 type1, param2 type2, ...)
  parameters : Array[FunctionParameter]
  /// Procedure body language (SQL, plpgsql, etc.)
  language : String?
  /// Procedure body/definition
  body : String?
  /// IF NOT EXISTS flag
  if_not_exists : Bool
} derive(Eq, Show)

///|
pub impl @pp.Pretty for CreateFunctionStmt with pretty(self) {
  @pp.text("CREATE FUNCTION ") +
  (if self.if_not_exists { @pp.text("IF NOT EXISTS ") } else { @pp.empty }) +
  @pp.text(self.name) +
  @pp.parens(
    @pp.separate(@pp.text(", "), self.parameters.map(@pp.pretty))
  ) +
  (match self.return_type {
    Some(ret_type) => @pp.text(" RETURNS ") + ret_type.pretty()
    None => @pp.empty
  }) +
  (match self.language {
    Some(lang) => @pp.text(" LANGUAGE ") + @pp.text(lang)
    None => @pp.empty
  }) +
  (if self.deterministic { @pp.text(" DETERMINISTIC") } else { @pp.empty }) +
  (match self.body {
    Some(body_text) => @pp.text(" AS ") + @pp.text("'") + @pp.text(body_text) + @pp.text("'")
    None => @pp.empty
  })
}

///|
pub impl @pp.Pretty for CreateProcedureStmt with pretty(self) {
  @pp.text("CREATE PROCEDURE ") +
  (if self.if_not_exists { @pp.text("IF NOT EXISTS ") } else { @pp.empty }) +
  @pp.text(self.name) +
  @pp.parens(
    @pp.separate(@pp.text(", "), self.parameters.map(@pp.pretty))
  ) +
  (match self.language {
    Some(lang) => @pp.text(" LANGUAGE ") + @pp.text(lang)
    None => @pp.empty
  }) +
  (match self.body {
    Some(body_text) => @pp.text(" AS ") + @pp.text("'") + @pp.text(body_text) + @pp.text("'")
    None => @pp.empty
  })
}

///|
/// CREATE SEQUENCE statement
pub struct CreateSequenceStmt {
  /// CREATE SEQUENCE <sequence_name>
  name : String
  /// IF NOT EXISTS flag
  if_not_exists : Bool
  /// TEMPORARY flag
  temporary : Bool
  /// INCREMENT BY value (default 1)
  increment : Int?
  /// MINVALUE value or NO MINVALUE
  minvalue : SequenceLimit?
  /// MAXVALUE value or NO MAXVALUE  
  maxvalue : SequenceLimit?
  /// START WITH value (default 1)
  start_with : Int?
  /// CACHE value
  cache : Int?
  /// CYCLE or NO CYCLE (default NO CYCLE)
  cycle : Bool?
  /// OWNED BY table.column or OWNED BY NONE
  owned_by : SequenceOwnedBy?
} derive(Eq, Show)

///|
/// Sequence limit specification
pub enum SequenceLimit {
  /// MINVALUE/MAXVALUE value
  Value(Int)
  /// NO MINVALUE/NO MAXVALUE
  NoLimit
} derive(Eq, Show)

///|
/// OWNED BY specification for sequences  
pub enum SequenceOwnedBy {
  /// OWNED BY table.column
  Column(ObjectName, String)
  /// OWNED BY NONE
  ByNone
} derive(Eq, Show)

///|
pub impl @pp.Pretty for CreateSequenceStmt with pretty(self) {
  @pp.text("CREATE ") +
  (if self.temporary { @pp.text("TEMPORARY ") } else { @pp.empty }) +
  @pp.text("SEQUENCE ") +
  (if self.if_not_exists { @pp.text("IF NOT EXISTS ") } else { @pp.empty }) +
  @pp.text(self.name) +
  (match self.increment {
    Some(inc) => @pp.text(" INCREMENT BY ") + @pp.text(inc.to_string())
    None => @pp.empty
  }) +
  (match self.minvalue {
    Some(SequenceLimit::Value(val)) => @pp.text(" MINVALUE ") + @pp.text(val.to_string())
    Some(SequenceLimit::NoLimit) => @pp.text(" NO MINVALUE")
    None => @pp.empty
  }) +
  (match self.maxvalue {
    Some(SequenceLimit::Value(val)) => @pp.text(" MAXVALUE ") + @pp.text(val.to_string())
    Some(SequenceLimit::NoLimit) => @pp.text(" NO MAXVALUE")
    None => @pp.empty
  }) +
  (match self.start_with {
    Some(start) => @pp.text(" START WITH ") + @pp.text(start.to_string())
    None => @pp.empty
  }) +
  (match self.cache {
    Some(cache_val) => @pp.text(" CACHE ") + @pp.text(cache_val.to_string())
    None => @pp.empty
  }) +
  (match self.cycle {
    Some(true) => @pp.text(" CYCLE")
    Some(false) => @pp.text(" NO CYCLE")
    None => @pp.empty
  }) +
  (match self.owned_by {
    Some(SequenceOwnedBy::Column(table, column)) => 
      @pp.text(" OWNED BY ") + table.pretty() + @pp.text(".") + @pp.text(column)
    Some(SequenceOwnedBy::ByNone) => @pp.text(" OWNED BY NONE")
    None => @pp.empty
  })
}

///|
pub impl @pp.Pretty for SequenceLimit with pretty(self) {
  match self {
    SequenceLimit::Value(val) => @pp.text(val.to_string())
    SequenceLimit::NoLimit => @pp.text("NO LIMIT")
  }
}

///|
pub impl @pp.Pretty for SequenceOwnedBy with pretty(self) {
  match self {
    SequenceOwnedBy::Column(table, column) => 
      table.pretty() + @pp.text(".") + @pp.text(column)
    SequenceOwnedBy::ByNone => @pp.text("NONE")
  }
}

///|
pub impl @pp.Pretty for FunctionParameter with pretty(self) {
  (match self.mode {
    Some(ParameterMode::In) => @pp.text("IN ")
    Some(ParameterMode::Out) => @pp.text("OUT ")
    Some(ParameterMode::InOut) => @pp.text("INOUT ")
    None => @pp.empty
  }) +
  @pp.text(self.name) + @pp.space + self.param_type.pretty()
}

///|
pub impl @pp.Pretty for ParameterMode with pretty(self) {
  match self {
    ParameterMode::In => @pp.text("IN")
    ParameterMode::Out => @pp.text("OUT")
    ParameterMode::InOut => @pp.text("INOUT")
  }
}

///|
pub struct DropViewStmt {
  // DROP VIEW <view_name>
  name : String
} derive(Eq, Show)

///|
pub impl @pp.Pretty for DropViewStmt with pretty(self) {
  @pp.text("DROP VIEW ") + @pp.text(self.name)
}

///|
pub enum DuplicateTreatment {
  // DISTINCT
  Distinct
  // ALL
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
  // <identifier>.<identifier>.<identifier>
  parts : Array[String]
} derive(Eq, Show)

///|
pub impl @pp.Pretty for ObjectName with pretty(self) {
  @pp.separate(@pp.text("."), self.parts.map(fn(part) {
    // Add backticks if the identifier contains spaces or special characters
    if part.contains(" ") || part.contains("-") || part.contains(".") {
      @pp.text("`" + part + "`")
    } else {
      @pp.text(part)
    }
  }))
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
  // INSERT INTO <table_name>
  table_name : ObjectName
  // Optional column list: (<col1>, <col2>, ...)
  columns : Array[String]
  // The inserted data source
  source : InsertSource
  // SQLite-style conflict resolution (OR REPLACE, etc.)
  or : SqliteOnConflict?
  // MySQL ON DUPLICATE KEY UPDATE or PostgreSQL ON CONFLICT
  on : OnInsert?
} derive(Eq, Show)

///|
pub impl @pp.Pretty for InsertStmt with pretty(self) {
  // Handle REPLACE vs INSERT OR REPLACE
  (match self.or {
    Some(SqliteOnConflict::Replace) => @pp.text("REPLACE INTO ")
    Some(conflict) => @pp.text("INSERT ") + conflict.pretty() + @pp.text(" INTO ")
    None => @pp.text("INSERT INTO ")
  }) +
  self.table_name.pretty() +
  (if self.columns.length() > 0 {
    @pp.space +
    @pp.parens(@pp.separate(@pp.text(", "), self.columns.map(@pp.text)))
  } else {
    @pp.empty
  }) +
  @pp.space +
  self.source.pretty() +
  (match self.on {
    Some(on_insert) => @pp.space + on_insert.pretty()
    None => @pp.empty
  })
}

///|
pub enum InsertSource {
  // VALUES (<expr>, ...), (<expr>, ...), ...
  Values(Array[Array[Expr]])
  // SELECT ...
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
  // UPDATE <table_name>
  table_name : ObjectName
  // SET assignments
  assignments : Array[Assignment]
  // Optional WHERE clause
  where_clause : Option[Expr]
} derive(Eq, Show)

///|
pub struct Assignment {
  // Column name
  column : String
  // Value expression
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
/// MERGE statement for conditional INSERT/UPDATE/DELETE operations
pub struct MergeStmt {
  /// Target table: MERGE INTO target_table
  target_table : ObjectName
  /// Target table alias: MERGE INTO target_table AS alias
  target_alias : String?
  /// Source table/query: USING source_table or USING (SELECT ...)
  source : MergeSource
  /// Source alias: USING source AS alias
  source_alias : String?
  /// Join condition: ON condition
  join_condition : Expr
  /// WHEN clauses defining actions
  when_clauses : Array[MergeWhenClause]
} derive(Eq, Show)

///|
/// Source for MERGE statement
pub enum MergeSource {
  /// Table source: USING table_name
  Table(ObjectName)
  /// Subquery source: USING (SELECT ...)
  Query(QueryStmt)
} derive(Eq, Show)

///|
/// WHEN clause in MERGE statement
pub struct MergeWhenClause {
  /// WHEN MATCHED / WHEN NOT MATCHED
  match_type : MergeMatchType
  /// Optional additional condition: WHEN MATCHED AND condition
  condition : Expr?
  /// Action to perform: INSERT / UPDATE / DELETE
  action : MergeAction
} derive(Eq, Show)

///|
/// Match type for WHEN clause
pub enum MergeMatchType {
  /// WHEN MATCHED
  Matched
  /// WHEN NOT MATCHED
  NotMatched
} derive(Eq, Show)

///|
/// Actions that can be performed in MERGE
pub enum MergeAction {
  /// INSERT (columns) VALUES (values)
  Insert(Array[String], Array[Expr])  // columns, values
  /// UPDATE SET assignments
  Update(Array[Assignment])
  /// DELETE (no parameters needed)
  Delete
} derive(Eq, Show)

///|
pub impl @pp.Pretty for MergeStmt with pretty(self) {
  @pp.text("MERGE INTO ") +
  self.target_table.pretty() +
  (match self.target_alias {
    Some(target_alias) => @pp.text(" AS ") + @pp.text(target_alias)
    None => @pp.empty
  }) +
  @pp.hardline +
  @pp.text("USING ") +
  self.source.pretty() +
  (match self.source_alias {
    Some(source_alias) => @pp.text(" AS ") + @pp.text(source_alias)
    None => @pp.empty
  }) +
  @pp.hardline +
  @pp.text("ON ") + self.join_condition.pretty() +
  (if self.when_clauses.is_empty() {
    @pp.empty
  } else {
    @pp.hardline +
    @pp.separate(
      @pp.hardline,
      self.when_clauses.map(fn(clause) { @pp.text("  ") + clause.pretty() })
    )
  })
}

///|
pub impl @pp.Pretty for MergeSource with pretty(self) {
  match self {
    MergeSource::Table(table) => table.pretty()
    MergeSource::Query(query) => 
      @pp.parens(@pp.nest(@pp.hardline + query.pretty()) + @pp.hardline)
  }
}

///|
pub impl @pp.Pretty for MergeWhenClause with pretty(self) {
  @pp.text("WHEN ") +
  self.match_type.pretty() +
  (match self.condition {
    Some(cond) => @pp.text(" AND ") + cond.pretty()
    None => @pp.empty
  }) +
  @pp.text(" THEN ") +
  self.action.pretty()
}

///|
pub impl @pp.Pretty for MergeMatchType with pretty(self) {
  match self {
    MergeMatchType::Matched => @pp.text("MATCHED")
    MergeMatchType::NotMatched => @pp.text("NOT MATCHED")
  }
}

///|
pub impl @pp.Pretty for MergeAction with pretty(self) {
  match self {
    MergeAction::Insert(columns, values) => {
      @pp.text("INSERT ") +
      (if columns.length() > 0 {
        @pp.parens(@pp.separate(@pp.text(", "), columns.map(@pp.text))) +
        @pp.space
      } else {
        @pp.empty
      }) +
      @pp.text("VALUES ") +
      @pp.parens(@pp.separate(@pp.text(", "), values.map(@pp.pretty)))
    }
    MergeAction::Update(assignments) =>
      @pp.text("UPDATE SET ") +
      @pp.separate(@pp.text(", "), assignments.map(@pp.pretty))
    MergeAction::Delete => @pp.text("DELETE")
  }
}

///|
pub struct TruncateStmt {
  // TRUNCATE <table_name>
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
pub struct DropIndexStmt {
  /// DROP INDEX <index_name>
  name : String
  /// IF EXISTS flag
  if_exists : Bool
  /// CONCURRENTLY flag (PostgreSQL)
  concurrently : Bool
  /// ON table_name (some dialects require table name)
  table_name : ObjectName?
} derive(Eq, Show)

///|
pub impl @pp.Pretty for DropIndexStmt with pretty(self) {
  @pp.text("DROP INDEX ") +
  (if self.concurrently { @pp.text("CONCURRENTLY ") } else { @pp.empty }) +
  (if self.if_exists { @pp.text("IF EXISTS ") } else { @pp.empty }) +
  @pp.text(self.name) +
  (match self.table_name {
    Some(table) => @pp.text(" ON ") + table.pretty()
    None => @pp.empty
  })
}

///|
pub struct AlterTableStmt {
  // ALTER TABLE <table_name>
  table_name : ObjectName
  // IF EXISTS flag
  if_exists : Bool
  // Table alteration operation
  operation : AlterTableOperation
} derive(Eq, Show)

///|
pub enum AlterTableOperation {
  // DROP COLUMN [IF EXISTS] <column_name>
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
/// ALTER INDEX statement
pub struct AlterIndexStmt {
  // ALTER INDEX <index_name>
  name : String
  // IF EXISTS flag  
  if_exists : Bool
  // Index alteration operation
  operation : AlterIndexOperation
} derive(Eq, Show)

///|
/// ALTER INDEX operations
pub enum AlterIndexOperation {
  /// RENAME TO new_name
  RenameTo(String)
  /// SET TABLESPACE tablespace_name
  SetTablespace(String)
  /// RESET (param1, param2, ...)
  Reset(Array[String])
  /// SET (param1 = value1, param2 = value2, ...)
  Set(Array[IndexParameter])
} derive(Eq, Show)

///|
/// Index parameter for SET operations
pub struct IndexParameter {
  name : String
  value : String
} derive(Eq, Show)

///|
pub impl @pp.Pretty for AlterIndexStmt with pretty(self) {
  @pp.text("ALTER INDEX ") +
  (if self.if_exists {
    @pp.text("IF EXISTS ")
  } else {
    @pp.empty
  }) +
  @pp.text(self.name) +
  @pp.space +
  self.operation.pretty()
}

///|
pub impl @pp.Pretty for AlterIndexOperation with pretty(self) {
  match self {
    AlterIndexOperation::RenameTo(new_name) =>
      @pp.text("RENAME TO ") + @pp.text(new_name)
    AlterIndexOperation::SetTablespace(tablespace) =>
      @pp.text("SET TABLESPACE ") + @pp.text(tablespace)
    AlterIndexOperation::Reset(params) =>
      @pp.text("RESET (") + @pp.separate(@pp.text(", "), params.map(@pp.text)) + @pp.text(")")
    AlterIndexOperation::Set(params) =>
      @pp.text("SET (") + @pp.separate(@pp.text(", "), params.map(@pp.pretty)) + @pp.text(")")
  }
}

///|
pub impl @pp.Pretty for IndexParameter with pretty(self) {
  @pp.text(self.name) + @pp.text(" = ") + @pp.text(self.value)
}

///|
/// MySQL SHOW statement
pub struct ShowStmt {
  // The type of SHOW statement
  show_type : ShowType
  // Optional object name (table, database, etc.)
  object : Option[ObjectName]
  // Optional filter condition
  filter : Option[ShowFilter]
  // Additional options
  extended : Bool  // SHOW EXTENDED ...
  full : Bool      // SHOW FULL ...
  global_scope : Bool  // GLOBAL/SESSION for STATUS/VARIABLES
} derive(Eq, Show)

///|
pub enum ShowType {
  Tables
  Columns
  Status
  Databases
  Schemas  // synonym for Databases
  Variables
  Processlist
  Grants
  Functions
  CreateTable
  CreateView
  CreateFunction
  CreateProcedure
  CreateEvent
  CreateTrigger
} derive(Eq, Show)

///|
pub enum ShowFilter {
  Like(String)
  Where(Expr)
} derive(Eq, Show)

///|
pub impl @pp.Pretty for ShowStmt with pretty(self) {
  @pp.text("SHOW ") +
  (if self.extended { @pp.text("EXTENDED ") } else { @pp.empty }) +
  (if self.full { @pp.text("FULL ") } else { @pp.empty }) +
  (if self.global_scope { @pp.text("GLOBAL ") } else { @pp.empty }) +
  self.show_type.pretty() +
  (match self.object {
    Some(obj) => {
      // For CREATE statements, object comes directly after type (no FROM)
      match self.show_type {
        ShowType::CreateTable | ShowType::CreateView | ShowType::CreateFunction | ShowType::CreateProcedure | ShowType::CreateEvent | ShowType::CreateTrigger => 
          @pp.space + obj.pretty()
        _ => @pp.space + @pp.text("FROM ") + obj.pretty()
      }
    }
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
    ShowType::Schemas => @pp.text("SCHEMAS")
    ShowType::Variables => @pp.text("VARIABLES")
    ShowType::Processlist => @pp.text("PROCESSLIST")
    ShowType::Grants => @pp.text("GRANTS")
    ShowType::Functions => @pp.text("FUNCTIONS")
    ShowType::CreateTable => @pp.text("CREATE TABLE")
    ShowType::CreateView => @pp.text("CREATE VIEW")
    ShowType::CreateFunction => @pp.text("CREATE FUNCTION")
    ShowType::CreateProcedure => @pp.text("CREATE PROCEDURE")
    ShowType::CreateEvent => @pp.text("CREATE EVENT")
    ShowType::CreateTrigger => @pp.text("CREATE TRIGGER")
  }
}

///|
pub impl @pp.Pretty for ShowFilter with pretty(self) {
  match self {
    ShowFilter::Like(pattern) => @pp.text("LIKE '") + @pp.text(pattern) + @pp.text("'")
    ShowFilter::Where(expr) => @pp.text("WHERE ") + expr.pretty()
  }
}

///|
pub struct SetStmt {
  // Variable scope (GLOBAL, SESSION, or LOCAL/user variables)
  scope : SetScope
  // Variable assignments
  assignments : Array[SetAssignment]
} derive(Eq, Show)

///|
pub enum SetScope {
  Global      // SET GLOBAL var = value
  Session     // SET SESSION var = value  
  UserVar     // SET @var = value
  Local       // Default scope (session for system vars)
} derive(Eq, Show)

///|
pub struct SetAssignment {
  // Variable name
  variable : String
  // Assigned value
  value : Expr
} derive(Eq, Show)

///|
pub impl @pp.Pretty for SetStmt with pretty(self) {
  @pp.text("SET ") +
  (match self.scope {
    SetScope::Global => @pp.text("GLOBAL ")
    SetScope::Session => @pp.text("SESSION ")
    SetScope::UserVar => @pp.empty
    SetScope::Local => @pp.empty
  }) +
  @pp.separate(@pp.text(", "), self.assignments.map(fn(a) { a.pretty() }))
}

///|
pub impl @pp.Pretty for SetAssignment with pretty(self) {
  (match self.variable {
    variable if variable.strip_prefix("@") != None => @pp.text(variable)
    variable => @pp.text(variable) 
  }) +
  @pp.text(" = ") +
  self.value.pretty()
}

///|
/// MySQL ON DUPLICATE KEY UPDATE or PostgreSQL ON CONFLICT
pub enum OnInsert {
  /// ON DUPLICATE KEY UPDATE (MySQL when the key already exists, then execute an update instead)
  DuplicateKeyUpdate(Array[Assignment])
  /// ON CONFLICT is a PostgreSQL and SQLite extension (future implementation)
  // OnConflict(OnConflict)
} derive(Eq, Show)

///|
pub impl @pp.Pretty for OnInsert with pretty(self) {
  match self {
    OnInsert::DuplicateKeyUpdate(assignments) =>
      @pp.text("ON DUPLICATE KEY UPDATE ") +
      @pp.separate(@pp.text(", "), assignments.map(@pp.pretty))
  }
}

///|
/// SQLite-style conflict resolution for INSERT statements
/// See: https://sqlite.org/lang_conflict.html
pub enum SqliteOnConflict {
  Rollback
  Abort
  Fail
  Ignore
  Replace
} derive(Eq, Show)

///|
pub impl @pp.Pretty for SqliteOnConflict with pretty(self) {
  match self {
    SqliteOnConflict::Rollback => @pp.text("OR ROLLBACK")
    SqliteOnConflict::Abort => @pp.text("OR ABORT")
    SqliteOnConflict::Fail => @pp.text("OR FAIL")
    SqliteOnConflict::Ignore => @pp.text("OR IGNORE")
    SqliteOnConflict::Replace => @pp.text("OR REPLACE")
  }
}

///|
// TCL (Transaction Control Language) statement structures

pub struct BeginStmt {
  // BEGIN [WORK] [TRANSACTION] or START TRANSACTION
  work : Bool      // whether WORK keyword was used
  transaction : Bool  // whether TRANSACTION keyword was used
} derive(Eq, Show)

///|
pub impl @pp.Pretty for BeginStmt with pretty(self) {
  @pp.text("BEGIN") +
  (if self.work { @pp.text(" WORK") } else { @pp.empty }) +
  (if self.transaction { @pp.text(" TRANSACTION") } else { @pp.empty })
}

///|
pub struct CommitStmt {
  // COMMIT [WORK] [TRANSACTION]
  work : Bool      // whether WORK keyword was used  
  transaction : Bool  // whether TRANSACTION keyword was used
} derive(Eq, Show)

///|
pub impl @pp.Pretty for CommitStmt with pretty(self) {
  @pp.text("COMMIT") +
  (if self.work { @pp.text(" WORK") } else { @pp.empty }) +
  (if self.transaction { @pp.text(" TRANSACTION") } else { @pp.empty })
}

///|
pub struct RollbackStmt {
  // ROLLBACK [WORK] [TRANSACTION] [TO [SAVEPOINT] savepoint_name]
  work : Bool      // whether WORK keyword was used
  transaction : Bool  // whether TRANSACTION keyword was used  
  savepoint : String? // optional savepoint name to rollback to
} derive(Eq, Show)

///|
pub impl @pp.Pretty for RollbackStmt with pretty(self) {
  @pp.text("ROLLBACK") +
  (if self.work { @pp.text(" WORK") } else { @pp.empty }) +
  (if self.transaction { @pp.text(" TRANSACTION") } else { @pp.empty }) +
  (match self.savepoint {
    Some(name) => @pp.text(" TO SAVEPOINT ") + @pp.text(name)
    None => @pp.empty
  })
}

///|
pub struct SavepointStmt {
  // SAVEPOINT savepoint_name
  name : String
} derive(Eq, Show)

///|
pub impl @pp.Pretty for SavepointStmt with pretty(self) {
  @pp.text("SAVEPOINT ") + @pp.text(self.name)
}

///|
pub struct ReleaseSavepointStmt {
  // RELEASE [SAVEPOINT] savepoint_name
  savepoint_keyword : Bool  // whether SAVEPOINT keyword was used
  name : String
} derive(Eq, Show)

///|
pub impl @pp.Pretty for ReleaseSavepointStmt with pretty(self) {
  @pp.text("RELEASE ") +
  (if self.savepoint_keyword { @pp.text("SAVEPOINT ") } else { @pp.empty }) +
  @pp.text(self.name)
}

///|
// DCL (Data Control Language) statement structures

pub struct GrantStmt {
  // GRANT privileges ON object TO grantees [WITH GRANT OPTION]
  privileges : Array[Privilege]
  objects : Array[ObjectName]    // tables, views, etc.
  grantees : Array[String]       // users or roles
  with_grant_option : Bool
} derive(Eq, Show)

///|
pub enum Privilege {
  // Basic privileges
  Select(Array[String]?)         // SELECT [(column_list)]
  Insert(Array[String]?)         // INSERT [(column_list)]
  Update(Array[String]?)         // UPDATE [(column_list)]
  Delete                         // DELETE
  References(Array[String]?)     // REFERENCES [(column_list)]
  // DDL privileges  
  Create                         // CREATE
  Drop                           // DROP
  Alter                          // ALTER
  Index                          // INDEX/CREATE INDEX
  // Special privileges
  All                           // ALL [PRIVILEGES]
  Usage                         // USAGE (for sequences, schemas)
  Execute                       // EXECUTE (for functions, procedures)
  Connect                       // CONNECT (for databases)
  Temporary                     // TEMPORARY/TEMP (for databases)
} derive(Eq, Show)

///|
pub impl @pp.Pretty for GrantStmt with pretty(self) {
  @pp.text("GRANT ") +
  @pp.separate(@pp.text(", "), self.privileges.map(@pp.pretty)) +
  @pp.text(" ON ") +
  @pp.separate(@pp.text(", "), self.objects.map(@pp.pretty)) +
  @pp.text(" TO ") +
  @pp.separate(@pp.text(", "), self.grantees.map(@pp.text)) +
  (if self.with_grant_option { @pp.text(" WITH GRANT OPTION") } else { @pp.empty })
}

///|
pub impl @pp.Pretty for Privilege with pretty(self) {
  match self {
    Privilege::Select(cols) => @pp.text("SELECT") + (match cols {
      Some(column_names) if column_names.length() > 0 =>
        @pp.parens(@pp.separate(@pp.text(", "), column_names.map(@pp.text)))
      _ => @pp.empty
    })
    Privilege::Insert(cols) => @pp.text("INSERT") + (match cols {
      Some(column_names) if column_names.length() > 0 =>
        @pp.parens(@pp.separate(@pp.text(", "), column_names.map(@pp.text)))
      _ => @pp.empty
    })
    Privilege::Update(cols) => @pp.text("UPDATE") + (match cols {
      Some(column_names) if column_names.length() > 0 =>
        @pp.parens(@pp.separate(@pp.text(", "), column_names.map(@pp.text)))
      _ => @pp.empty
    })
    Privilege::Delete => @pp.text("DELETE")
    Privilege::References(cols) => @pp.text("REFERENCES") + (match cols {
      Some(column_names) if column_names.length() > 0 =>
        @pp.parens(@pp.separate(@pp.text(", "), column_names.map(@pp.text)))
      _ => @pp.empty
    })
    Privilege::Create => @pp.text("CREATE")
    Privilege::Drop => @pp.text("DROP")
    Privilege::Alter => @pp.text("ALTER")
    Privilege::Index => @pp.text("INDEX")
    Privilege::All => @pp.text("ALL PRIVILEGES")
    Privilege::Usage => @pp.text("USAGE")
    Privilege::Execute => @pp.text("EXECUTE")
    Privilege::Connect => @pp.text("CONNECT")
    Privilege::Temporary => @pp.text("TEMPORARY")
  }
}

///|
pub struct RevokeStmt {
  // REVOKE [GRANT OPTION FOR] privileges ON object FROM grantees [RESTRICT | CASCADE]
  grant_option_for : Bool        // whether GRANT OPTION FOR was specified
  privileges : Array[Privilege]
  objects : Array[ObjectName]    // tables, views, etc.
  grantees : Array[String]       // users or roles
  cascade : RevokeOption?        // RESTRICT | CASCADE
} derive(Eq, Show)

///|
pub enum RevokeOption {
  Restrict                       // RESTRICT
  Cascade                        // CASCADE
} derive(Eq, Show)

///|
pub impl @pp.Pretty for RevokeStmt with pretty(self) {
  @pp.text("REVOKE ") +
  (if self.grant_option_for { @pp.text("GRANT OPTION FOR ") } else { @pp.empty }) +
  @pp.separate(@pp.text(", "), self.privileges.map(@pp.pretty)) +
  @pp.text(" ON ") +
  @pp.separate(@pp.text(", "), self.objects.map(@pp.pretty)) +
  @pp.text(" FROM ") +
  @pp.separate(@pp.text(", "), self.grantees.map(@pp.text)) +
  (match self.cascade {
    Some(RevokeOption::Restrict) => @pp.text(" RESTRICT")
    Some(RevokeOption::Cascade) => @pp.text(" CASCADE")
    None => @pp.empty
  })
}

///|
pub impl @pp.Pretty for RevokeOption with pretty(self) {
  match self {
    RevokeOption::Restrict => @pp.text("RESTRICT")
    RevokeOption::Cascade => @pp.text("CASCADE")
  }
}
