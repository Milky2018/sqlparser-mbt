///|
suberror ParserError {
  UnexpectedTokenError(Token)
  UnimplementedError(String)
  InternalBug(String)
}

///|
struct Parser {
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
  if self.current() == Some(expected) {
    self.advance()
  } else {
    raise UnexpectedTokenError(expected)
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
pub fn Parser::parse(self : Self) -> Statement raise ParserError {
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
    Some(start) => raise UnexpectedTokenError(start)
    None => raise InternalBug("parse_statement")
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
  {
    projections,
    from,
    where_clause: None, // TODO: 
    group_by: [], // TODO: 
    having: None, // TODO:
    order_by: [], // TODO:
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
            Some(unknown_token) => raise UnexpectedTokenError(unknown_token)
            None => raise InternalBug("parse_projections")
          }
        } else {
          Projection::UnamedExpr(expr)
        }

      }
      None => raise InternalBug("parse_projections")
    }
    projections.push(proj)
    if not(self.eat(Token::Comma)) {
      return projections
    }
  }
}

fn Parser::parse_expr(self : Self) -> Expr raise ParserError {
  self.parse_primary_expr() // TODO: binary operation
}

fn Parser::parse_primary_expr(self : Self) -> Expr raise ParserError {
  match self.current() {
    Some(Number(n)) => {
      self.advance()
      if n.contains_char('.') {
        let v = try {
          @strconv.parse_double(n)
        } catch {
          StrConvError(e) => raise InternalBug("parse_primary_expr: \{e}")
        }
        Expr::Literal(Literal::Double(v))
      } else {
        let v = try {
          @strconv.parse_int(n)
        } catch {
          StrConvError(e) => raise InternalBug("parse_primary_expr: \{e}")
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
      Expr::Identifier(name)
    }
    Some(_) => {
      raise UnimplementedError("parse_primary_expr")
    }
    None => {
      raise InternalBug("parse_primary_expr")
    }
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
            Some(unknown_token) => raise UnexpectedTokenError(unknown_token)
            None => raise InternalBug("parse_table_refs")
          }
        } else {
          table_refs.push(TableRef::Table(name))
        }
      }
      _ => return table_refs
    }
  }
}

///|
test "Parse simple select statement" {
  let input = [
    Token::Select,
    Token::Mul,
    Token::From,
    Token::Identifier("table"),
    Token::Semicolon,
  ]
  let parser = Parser::new(input)
  let stmt = parser.parse() catch {
    UnexpectedTokenError(token) => {
      println("Unexpected token: \{token}")
      panic()
    }
    InternalBug(msg) => {
      println("Internal bug: \{msg}")
      panic()
    }
    UnimplementedError(msg) => {
      println("Unimplemented: \{msg}")
      panic()
    }
  }
  inspect(stmt, content="SELECT * FROM Table(\"table\");")
}
