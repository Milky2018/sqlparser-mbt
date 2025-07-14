///|
suberror ParserError {
  UnexpectedTokenError(Token, Token)
  UnexpectedTokenMessageError(Token, String)
  UnimplementedError(String)
  InternalBug(String)
} derive(Show)

///|
pub struct Parser {
  input : Array[Token]
  mut offset : Int
}

///|
fn Parser::new(input : Array[Token]) -> Parser {
  { input, offset: 0 }
}

///|
fn Parser::current(self : Self) -> Token? {
  self.peek(0)
}

///|
fn Parser::advance(self : Self) -> Unit {
  self.offset += 1
}

///|
fn Parser::expect(self : Self, expected : Token) -> Unit raise ParserError {
  let cur = self.current()
  match cur {
    Some(c) if c == expected => self.advance()
    Some(c) => raise UnexpectedTokenError(c, expected)
    None =>
      raise ParserError::InternalBug("expect: expected \{expected}, got None")
  }
}

///|
fn Parser::eat(self : Self, expected : Token) -> Bool {
  if self.current() == Some(expected) {
    self.advance()
    true
  } else {
    false
  }
}

///|
fn Parser::eat_tokens(self : Self, expected : Array[Token]) -> Bool {
  for i, token in expected {
    if self.input.get(self.offset + i) != Some(token) {
      return false
    }
  }
  self.offset += expected.length()
  true
}

///|
fn Parser::peek(self : Self, nth : Int) -> Token? {
  self.input.get(self.offset + nth)
}

///|
fn Parser::parse(self : Self) -> Statement raise ParserError {
  let stmt = self.parse_statement()
  self.eat(Token::Eof) |> ignore
  stmt
}

///|
fn Parser::parse_statement(self : Self) -> Statement raise ParserError {
  let stmt = match self.current() {
    Some(Keyword(Select)) => {
      let select_stmt = self.parse_select_statement()
      Statement::Select(select_stmt)
    }
    Some(start) =>
      raise UnexpectedTokenMessageError(start, "SQL statement starter")
    None => raise ParserError::InternalBug("parse_statement")
  }
  self.eat(Token::Semicolon) |> ignore
  stmt
}

///|
fn Parser::parse_select_statement(self : Self) -> SelectStmt raise ParserError {
  self.expect(Keyword(Select))
  let projections = self.parse_projections()
  self.expect(Keyword(From))
  let from = self.parse_table_refs()
  let where_clause = if self.eat(Keyword(Where)) {
    Some(self.parse_expr())
  } else {
    None
  }
  let group_by = if self.eat(Keyword(Group)) {
    self.expect(Keyword(By))
    self.parse_group_by()
  } else {
    []
  }
  let order_by = if self.eat(Keyword(Order)) {
    self.expect(Keyword(By))
    self.parse_order_by()
  } else {
    []
  }
  {
    projections,
    from,
    where_clause,
    group_by,
    having: None, // TODO:
    order_by,
    limit: None, // TODO:
    offset: None, // TODO:
  }
}

///|
fn Parser::parse_projections(
  self : Self
) -> Array[Projection] raise ParserError {
  let projections = []
  for {
    let proj = match self.current() {
      Some(Token::Mul) => {
        self.advance()
        Projection::Wildcard
      }
      Some(_) => {
        let expr = self.parse_expr()
        if self.eat(Keyword(As)) {
          match self.current() {
            Some(Identifier(alias_name)) => {
              self.advance()
              Projection::AliasedExpr(expr, alias_name)
            }
            Some(unknown_token) =>
              raise UnexpectedTokenMessageError(unknown_token, "alias name")
            None => raise ParserError::InternalBug("parse_projections")
          }
        } else {
          Projection::UnamedExpr(expr)
        }
      }
      None => raise ParserError::InternalBug("parse_projections")
    }
    projections.push(proj)
    if not(self.eat(Token::Comma)) {
      return projections
    }
  }
}

///|
fn Parser::parse_expr(self : Self) -> Expr raise ParserError {
  self.parse_binary_expr(0)
}

///|
fn Parser::get_next_bp(self : Self) -> Int raise ParserError {
  if self.try_binary_operator() is Some(op) {
    op.get_precedence().value()
  } else {
    match self.current() {
      Some(Keyword(Like)) | Some(Keyword(ILike)) => Precedence::Like.value()
      Some(Keyword(Not)) =>
        match self.peek(1) {
          Some(Keyword(Like)) | Some(Keyword(ILike)) => Precedence::Like.value()
          Some(unknown) =>
            raise UnexpectedTokenMessageError(
              unknown, "expected 'LIKE' or 'ILIKE' after 'NOT'",
            )
          None =>
            raise ParserError::InternalBug(
              "get_next_bp: unexpected end of input after 'NOT'",
            )
        }
      _ => 0
    }
  }
}

///|
fn Parser::parse_binary_expr(
  self : Self,
  min_bp : Int
) -> Expr raise ParserError {
  let mut expr = self.parse_primary_expr()
  for {
    let next_bp = self.get_next_bp()
    if next_bp <= min_bp {
      return expr
    }
    expr = self.parse_infix(expr, next_bp)
  }
}

///|
fn Parser::parse_infix(
  self : Self,
  left : Expr,
  min_bp : Int
) -> Expr raise ParserError {
  if self.try_binary_operator() is Some(op) {
    self.advance()
    let right = self.parse_binary_expr(min_bp)
    Expr::BinaryOperation(left, op, right)
  } else if self.eat_tokens([Keyword(Like)]) {
    Expr::Like(positive=true, left, self.parse_binary_expr(min_bp))
  } else if self.eat_tokens([Keyword(ILike)]) {
    Expr::ILike(positive=true, left, self.parse_binary_expr(min_bp))
  } else if self.eat_tokens([Keyword(Not), Keyword(Like)]) {
    Expr::Like(positive=false, left, self.parse_binary_expr(min_bp))
  } else if self.eat_tokens([Keyword(Not), Keyword(ILike)]) {
    Expr::ILike(positive=false, left, self.parse_binary_expr(min_bp))
  } else {
    left
  }
}

///|
fn Parser::try_binary_operator(self : Self) -> BinaryOperator? {
  match self.current() {
    Some(token) =>
      match token {
        Token::Mul => Some(BinaryOperator::Mul)
        Token::Plus => Some(BinaryOperator::Plus)
        Token::Minus => Some(BinaryOperator::Minus)
        Token::Div => Some(BinaryOperator::Div)
        Token::Mod => Some(BinaryOperator::Mod)
        Token::Eq => Some(BinaryOperator::Eq)
        Token::Neq => Some(BinaryOperator::Neq)
        Token::Lt => Some(BinaryOperator::Lt)
        Token::Gt => Some(BinaryOperator::Gt)
        Token::LtEq => Some(BinaryOperator::LtEq)
        Token::GtEq => Some(BinaryOperator::GtEq)
        Token::Spaceship => Some(BinaryOperator::Spaceship)
        Keyword(And) => Some(BinaryOperator::And)
        Keyword(Or) => Some(BinaryOperator::Or)
        _ => None
      }
    None => None
  }
}

///|
fn Parser::parse_primary_expr(self : Self) -> Expr raise ParserError {
  match self.current() {
    Some(Number(n)) => {
      self.advance()
      if n.contains_char('.') {
        let v = @strconv.parse_double(n) catch {
          StrConvError(e) =>
            raise ParserError::InternalBug("parse_primary_expr: \{e}")
        }
        Expr::Literal(Literal::Double(v))
      } else {
        let v = @strconv.parse_int(n) catch {
          StrConvError(e) =>
            raise ParserError::InternalBug("parse_primary_expr: \{e}")
        }
        Expr::Literal(Literal::Integer(v))
      }
    }
    Some(StringLiteral(s)) => {
      self.advance()
      Expr::Literal(Literal::String(s))
    }
    Some(Keyword(Date)) => self.parse_date_expr()
    Some(Keyword(Interval)) => self.parse_interval_expr()
    Some(Identifier(name)) => {
      self.advance()
      if self.current() == Some(Token::LParen) {
        let args = []
        self.advance()
        if not(self.eat(Token::RParen)) {
          for {
            let arg = self.parse_expr()
            args.push(arg)
            if self.eat(Token::Comma) {
              continue
            } else {
              self.expect(Token::RParen)
              break
            }
          }
        }
        Expr::FunctionCall(name, args)
      } else {
        Expr::Identifier(name)
      }
    }
    Some(Token::LParen) => {
      self.advance()
      let expr = self.parse_expr()
      self.expect(Token::RParen)
      expr
    }
    Some(Token::Mul) => {
      self.advance()
      Expr::Wildcard
    }
    Some(token) => raise UnimplementedError("parse_primary_expr: \{token}")
    None => raise ParserError::InternalBug("parse_primary_expr")
  }
}

///|
fn Parser::parse_table_refs(self : Self) -> Array[TableRef] raise ParserError {
  let table_refs = []
  loop self.current() {
    Some(Identifier(name)) => {
      self.advance()
      if self.eat(Keyword(As)) {
        match self.current() {
          Some(Identifier(alias_name)) => {
            self.advance()
            table_refs.push(TableRef::TableAlias(name, alias_name))
          }
          Some(unknown_token) =>
            raise UnexpectedTokenMessageError(unknown_token, "alias name")
          None => raise ParserError::InternalBug("parse_table_refs")
        }
      } else {
        table_refs.push(TableRef::Table(name))
      }
      if self.eat(Token::Comma) {
        continue self.current()
      } else {
        break table_refs
      }
    }
    Some(unknown) =>
      raise UnexpectedTokenMessageError(
        unknown, "expected a table name or identifier",
      )
    None => raise ParserError::InternalBug("parse_table_refs")
  }
}

///|
fn Parser::parse_group_by(self : Self) -> Array[Expr] raise ParserError {
  let group_by = []
  for {
    let expr = self.parse_expr()
    group_by.push(expr)
    if not(self.eat(Token::Comma)) {
      return group_by
    }
  }
  raise ParserError::InternalBug("parse_group_by: unexpected end of input")
}

///|
fn Parser::parse_order_by(self : Self) -> Array[OrderByExpr] raise ParserError {
  let order_by = []
  for {
    let order_by_expr = self.parse_order_by_expr()
    order_by.push(order_by_expr)
    if not(self.eat(Token::Comma)) {
      return order_by
    }
  }
  raise ParserError::InternalBug("parse_order_by: unexpected end of input")
}

///|
fn Parser::parse_order_by_expr(self : Self) -> OrderByExpr raise ParserError {
  let expr = self.parse_expr()
  let asc = if self.eat(Keyword(Asc)) {
    Some(true)
  } else if self.eat(Keyword(Desc)) {
    Some(false)
  } else {
    None
  }
  let nulls_first = if self.eat(Keyword(Nulls)) {
    if self.eat(Keyword(First)) {
      Some(true)
    } else if self.eat(Keyword(Last)) {
      Some(false)
    } else {
      raise UnexpectedTokenMessageError(
        self.current().unwrap(),
        "expected 'FIRST' or 'LAST' after 'NULLS'",
      )
    }
  } else {
    None
  }
  { expr, asc, nulls_first }
}

///|
fn Parser::parse_date_expr(self : Self) -> Expr raise ParserError {
  self.expect(Keyword(Date))
  match self.current() {
    Some(Token::StringLiteral(s)) => {
      self.advance()
      Expr::Datetime(s)
    }
    Some(unknown_token) =>
      raise UnexpectedTokenMessageError(
        unknown_token, "expected a string literal after 'DATE'",
      )
    None =>
      raise ParserError::InternalBug("parse_date_expr: unexpected end of input")
  }
}

///|
fn Parser::parse_interval_expr(self : Self) -> Expr raise ParserError {
  self.expect(Keyword(Interval))
  match self.current() {
    Some(Token::StringLiteral(s)) => {
      self.advance()
      let qualifier = self.parse_interval_qualifier()
      Expr::Interval(s, qualifier)
    }
    Some(unknown_token) =>
      raise UnexpectedTokenMessageError(
        unknown_token, "expected a string literal after 'INTERVAL'",
      )
    None =>
      raise ParserError::InternalBug(
        "parse_interval_expr: unexpected end of input",
      )
  }
}

///|
fn Parser::parse_interval_qualifier(
  self : Self
) -> IntervalQualifier raise ParserError {
  let field1 = self.parse_primary_datetime_field()
  if self.eat(Keyword(To)) {
    let field2 = self.parse_primary_datetime_field()
    IntervalQualifier::Range(field1, field2)
  } else {
    IntervalQualifier::Single(field1)
  }
}

///|
fn Parser::parse_primary_datetime_field(
  self : Self
) -> PrimaryDatetimeField raise ParserError {
  match self.current() {
    Some(keyword) if datetime_unit_from_keyword(keyword) is Some(field) => {
      self.advance()
      let precision = if self.eat(Token::LParen) {
        match self.current() {
          Some(Number(n)) => {
            self.advance()
            self.expect(Token::RParen)
            let p = @strconv.parse_int(n) catch {
              StrConvError(e) =>
                raise ParserError::InternalBug(
                  "parse_primary_datetime_field: \{e}",
                )
            }
            Some(p)
          }
          Some(other) =>
            raise UnexpectedTokenMessageError(
              other, "expected a number after '('",
            )
          None => raise ParserError::InternalBug("parse_primary_datetime_field")
        }
      } else {
        None
      }
      { field, precision }
    }
    Some(other) =>
      raise UnexpectedTokenMessageError(
        other, "expected a primary datetime field keyword (YEAR, MONTH, etc.)",
      )
    None =>
      raise ParserError::InternalBug(
        "parse_primary_datetime_field: unexpected end of input",
      )
  }
}

///|
fn datetime_unit_from_keyword(keyword : Token) -> DatetimeUnit? {
  match keyword {
    Keyword(Year) => Some(Year)
    Keyword(Month) => Some(Month)
    Keyword(Day) => Some(Day)
    Keyword(Hour) => Some(Hour)
    Keyword(Minute) => Some(Minute)
    Keyword(Second) => Some(Second)
    _ => None
  }
}

///|
test "Parse simple select statement" {
  let input = [
    Keyword(Select),
    Token::Mul,
    Keyword(From),
    Token::Identifier("t"),
    Token::Semicolon,
  ]
  let parser = Parser::new(input)
  let stmt = parser.parse()
  inspect(stmt, content="SELECT * FROM t;")
}

///|
test "Parse select with two columns" {
  let input = "SELECT col1, col2 FROM t;"
  let stmt = parse_sql(input)
  inspect(stmt, content="SELECT col1, col2 FROM t;")
}

///|
test "Parse select with function call" {
  let input = "SELECT MAX(arg1, arg2), MIN() as m FROM t;"
  let stmt = parse_sql(input)
  inspect(stmt, content="SELECT max(arg1, arg2), min() AS m FROM t;")
}

///|
test "Nested expression" {
  let input = "SELECT sum(l_extendedprice * (1 - l_discount)) FROM lineitem;"
  let stmt = parse_sql(input)
  inspect(
    stmt,
    content="SELECT sum((l_extendedprice * (1 - l_discount))) FROM lineitem;",
  )
}

///|
test "Binary expression" {
  let input = "SELECT 1 + 2 * 3 FROM t;"
  let stmt = parse_sql(input)
  inspect(stmt, content="SELECT (1 + (2 * 3)) FROM t;")
}

///|
test "Complecated binary expression" {
  let input = "SELECT sum(a * (1 - b) * (2 + b)) AS c FROM t;"
  let stmt = parse_sql(input)
  inspect(stmt, content="SELECT sum(((a * (1 - b)) * (2 + b))) AS c FROM t;")
}

///|
test "Selection clause" {
  let input = "SELECT * FROM t WHERE id = 1;"
  let stmt = parse_sql(input)
  inspect(stmt, content="SELECT * FROM t WHERE (id = 1);")
}

///|
test "Like, ilike, not like, not ilike" {
  let input = "SELECT * FROM t WHERE name LIKE 'test' AND name ILIKE 'TEST' AND name NOT LIKE 'test2' AND name NOT ILIKE 'TEST2';"
  let stmt = parse_sql(input)
  inspect(
    stmt,
    content=
      #|SELECT * FROM t WHERE ((((name LIKE "test") AND (name ILIKE "TEST")) AND (name NOT LIKE "test2")) AND (name NOT ILIKE "TEST2"));
    ,
  )
}

///|
test "From multiple table refs" {
  let input = "SELECT * FROM t1, t2;"
  let stmt = parse_sql(input)
  inspect(stmt, content="SELECT * FROM t1, t2;")
}
