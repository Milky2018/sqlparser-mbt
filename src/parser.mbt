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
  self.input.get(self.offset)
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
fn Parser::parse(self : Self) -> Statement raise ParserError {
  let stmt = self.parse_statement()
  self.eat(Token::Eof) |> ignore
  stmt
}

///|
fn Parser::parse_statement(self : Self) -> Statement raise ParserError {
  let stmt = match self.current() {
    Some(Token::Select) => {
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
  self.expect(Token::Select)
  let projections = self.parse_projections()
  self.expect(Token::From)
  let from = self.parse_table_refs()
  let where_clause = if self.eat(Token::Where) {
    Some(self.parse_expr())
  } else {
    None
  }
  let group_by = if self.eat(Token::Group) {
    self.expect(Token::By)
    self.parse_group_by()
  } else {
    []
  }
  let order_by = if self.eat(Token::Order) {
    self.expect(Token::By)
    self.parse_order_by()
  } else {
    []
  }
  {
    projections,
    from,
    where_clause,
    group_by: [], // TODO: 
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
        if self.eat(Token::As) {
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
fn BinaryOperator::get_bp(self : Self) -> Int {
  match self {
    BinaryOperator::Plus | BinaryOperator::Minus => 30
    BinaryOperator::Mul | BinaryOperator::Div | BinaryOperator::Mod => 40
    BinaryOperator::Eq
    | BinaryOperator::Neq
    | BinaryOperator::Lt
    | BinaryOperator::Gt
    | BinaryOperator::LtEq
    | BinaryOperator::GtEq
    | BinaryOperator::Spaceship => 50
  }
}

///|
fn Parser::parse_binary_expr(
  self : Self,
  min_bp : Int
) -> Expr raise ParserError {
  let mut lhs = self.parse_primary_expr()
  for {
    let op = self.try_binary_operator()
    match op {
      Some(op) if op.get_bp() >= min_bp => {
        self.advance()
        let rhs = self.parse_binary_expr(op.get_bp() + 1)
        lhs = Expr::BinaryOperation(lhs, op, rhs)
      }
      _ => return lhs
    }
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
    Some(Identifier(name)) => {
      self.advance()
      match self.current() {
        Some(Token::LParen)  => {
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
        }
        _ => Expr::Identifier(name)
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
  for {
    match self.current() {
      Some(Identifier(name)) => {
        self.advance()
        if self.eat(Token::As) {
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
      }
      _ => return table_refs
    }
  }
}

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

fn Parser::parse_order_by_expr(self : Self) -> OrderByExpr raise ParserError {
  let expr = self.parse_expr()
  let asc = if self.eat(Token::Asc) {
    Some(true)
  } else if self.eat(Token::Desc) {
    Some(false)
  } else {
    None
  }
  let nulls_first = if self.eat(Token::Nulls) {
    if self.eat(Token::First) {
      Some(true)
    } else if self.eat(Token::Last) {
      Some(false)
    } else {
      raise UnexpectedTokenMessageError(
        self.current().unwrap(),
        "expected 'FIRST' or 'LAST' after 'NULLS'"
      )
    }
  } else {
    None
  }
  { expr, asc, nulls_first }
}

///|
test "Parse simple select statement" {
  let input = [
    Token::Select,
    Token::Mul,
    Token::From,
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
