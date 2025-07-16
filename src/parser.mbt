///|
suberror ParserError {
  UnexpectedTokenError(Token, Token)
  UnexpectedTokenMessageError(Token, String)
  MultipleElseInCaseExprError
  UnimplementedError(String)
  InternalBug(String)
} derive(Show)

///|
pub struct Parser {
  input : Array[Token]
  mut offset : Int
}

///|
pub fn Parser::new(input : Array[Token]) -> Parser {
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
fn[T] Parser::try_parse(self : Self, p : (Self) -> T raise ParserError) -> T? {
  let start_offset = self.offset
  Some(p(self)) catch {
    _ => {
      self.offset = start_offset
      None
    }
  }
}

///|
pub fn Parser::parse(self : Self) -> Statement raise ParserError {
  let stmt = self.parse_statement()
  match self.current() {
    Some(Token::Eof) => stmt
    Some(other) =>
      raise UnexpectedTokenMessageError(other, "expected end of SQL")
    None => stmt
  }
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
  match self.current() {
    Some(Token::Semicolon) => self.advance()
    Some(other) =>
      raise UnexpectedTokenMessageError(other, "expected ';' at the end of SQL")
    None => raise ParserError::InternalBug("parse_statement: unexpected end")
  }
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
  let having = if self.eat(Keyword(Having)) {
    Some(self.parse_expr())
  } else {
    None
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
    having,
    order_by,
    limit: None, // TODO:
    offset: None, // TODO:
  }
}

///|
fn Parser::parse_aliasing(
  self : Self,
  error_msg : String
) -> TableAlias? raise ParserError {
  if self.eat(Keyword(As)) {
    match self.current() {
      Some(Identifier(alias_name)) => {
        let columns = []
        self.advance()
        if self.eat(LParen) {
          loop self.current() {
            Some(Identifier(col_name)) => {
              self.advance()
              columns.push(col_name)
              if not(self.eat(Token::Comma)) {
                self.expect(RParen)
                break
              }
              continue self.current()
            }
            Some(other) =>
              raise UnexpectedTokenMessageError(
                other, "expected column name in aliasing",
              )
            None =>
              raise ParserError::InternalBug(
                "parse_aliasing: unexpected end of input",
              )
          }
        }
        return Some({ name: alias_name, columns })
      }
      Some(unknown_token) =>
        raise UnexpectedTokenMessageError(unknown_token, error_msg)
      None => raise ParserError::InternalBug("parse_aliasing")
    }
  } else if self.current() is Some(Identifier(alias_name)) {
    self.advance()
    return Some({ name: alias_name, columns: [] })
  } else {
    return None
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
        let optional_alias = if self.eat(Keyword(As)) {
          match self.current() {
            Some(Identifier(alias_name)) => {
              self.advance()
              Some(alias_name)
            }
            Some(unknown_token) =>
              raise UnexpectedTokenMessageError(
                unknown_token, "expected alias name after 'AS'",
              )
            None =>
              raise ParserError::InternalBug(
                "parse_projections: unexpected end of input",
              )
          }
        } else if self.current() is Some(Identifier(alias_name)) {
          self.advance()
          Some(alias_name)
        } else {
          None
        }
        match optional_alias {
          Some(alias_name) => Projection::AliasedExpr(expr, alias_name)
          None => Projection::UnamedExpr(expr)
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
          Some(Keyword(Between)) | Some(Keyword(In)) =>
            Precedence::Between.value()
          Some(unknown) =>
            raise UnexpectedTokenMessageError(
              unknown, "expected 'LIKE' or 'ILIKE' after 'NOT'",
            )
          None =>
            raise ParserError::InternalBug(
              "get_next_bp: unexpected end of input after 'NOT'",
            )
        }
      Some(Keyword(Between)) | Some(Keyword(In)) => Precedence::Between.value()
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
  } else if self.eat_tokens([Keyword(Between)]) {
    self.parse_between_expr(left, true)
  } else if self.eat_tokens([Keyword(Not), Keyword(Between)]) {
    self.parse_between_expr(left, false)
  } else if self.eat_tokens([Keyword(In)]) {
    self.parse_in_expr(left, true)
  } else if self.eat_tokens([Keyword(Not), Keyword(In)]) {
    self.parse_in_expr(left, false)
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
    Some(Minus) | Some(Plus) => {
      self.advance()
      let expr = self.parse_binary_expr(Precedence::MulDivMod.value())
      let op = if self.current() == Some(Minus) {
        self.advance()
        UnaryOperator::Minus
      } else {
        UnaryOperator::Plus
      }
      Expr::UnaryOperation(op, expr)
    }
    Some(Boolean(b)) => {
      self.advance()
      Expr::Literal(Literal::Boolean(b))
    }
    Some(Null) => {
      self.advance()
      Expr::Literal(Literal::Null)
    }
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
    Some(Keyword(Extract)) => self.parse_extract_expr()
    Some(Identifier(name)) => {
      self.advance()
      if self.eat(Token::LParen) {
        let args = []
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
      } else if self.eat(Token::Period) {
        let parts = [name]
        loop self.current() {
          Some(Token::Identifier(part)) => {
            self.advance()
            parts.push(part)
            if self.eat(Token::Period) {
              continue self.current()
            } else {
              break Expr::CompoundIdentifier(parts)
            }
          }
          Some(other) =>
            raise UnexpectedTokenMessageError(
              other, "expected another identifier after '.'",
            )
          None => raise ParserError::InternalBug("parse_primary_expr")
        }
      } else {
        Expr::Identifier(name)
      }
    }
    Some(Keyword(Exists)) => {
      self.advance()
      self.expect(Token::LParen)
      let sub_query = self.parse_select_statement()
      self.expect(Token::RParen)
      Exists(positive=true, sub_query)
    }
    Some(Keyword(Not)) => {
      self.advance()
      if self.eat(Keyword(Exists)) {
        self.expect(Token::LParen)
        let sub_query = self.parse_select_statement()
        self.expect(Token::RParen)
        Exists(positive=false, sub_query)
      } else {
        let expr = self.parse_binary_expr(Precedence::UnaryNot.value())
        Expr::UnaryOperation(UnaryOperator::Not, expr)
      }
    }
    Some(Keyword(Case)) => self.parse_case_expr()
    Some(Token::LParen) => {
      self.advance()
      if self.try_parse(Parser::parse_select_statement) is Some(sub_query) {
        self.expect(Token::RParen)
        Expr::SubQuery(sub_query)
      } else {
        let expr = self.parse_expr()
        self.expect(Token::RParen)
        expr
      }
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
    Some(Identifier(_)) | Some(LParen) => {
      table_refs.push(self.parse_table_ref())
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
fn Parser::parse_table_ref(self : Self) -> TableRef raise ParserError {
  let factor = self.parse_table_factor()
  let joins = []
  for {
    match self.current() {
      Some(Keyword(Join))
      | Some(Keyword(Left))
      | Some(Keyword(Right))
      | Some(Keyword(Full))
      | Some(Keyword(Inner)) => {
        let join_operator_maker = if self.eat_tokens([Keyword(Join)]) {
          JoinOperator::Join(_)
        } else if self.eat_tokens([Keyword(Left), Keyword(Join)]) {
          Left(_)
        } else if self.eat_tokens([Keyword(Left), Keyword(Outer), Keyword(Join)]) {
          LeftOuter(_)
        } else if self.eat_tokens([Keyword(Right), Keyword(Join)]) {
          Right(_)
        } else if self.eat_tokens([
            Keyword(Right),
            Keyword(Outer),
            Keyword(Join),
          ]) {
          RightOuter(_)
        } else if self.eat_tokens([Keyword(Full), Keyword(Join)]) {
          Full(_)
        } else if self.eat_tokens([Keyword(Full), Keyword(Outer), Keyword(Join)]) {
          FullOuter(_)
        } else if self.eat_tokens([Keyword(Inner), Keyword(Join)]) {
          Inner(_)
        } else {
          raise UnexpectedTokenMessageError(
            self.current().unwrap(),
            "expected 'JOIN', 'LEFT JOIN', 'RIGHT JOIN', 'FULL JOIN', 'INNER JOIN', or 'CROSS JOIN'",
          )
        }
        let table_ref = self.parse_table_ref()
        if self.eat(Keyword(On)) {
          let constraint = self.parse_expr()
          joins.push({
            join_operator: join_operator_maker(On(constraint)),
            table_ref,
          })
        } else if self.eat(Keyword(Using)) {
          let columns = []
          self.expect(LParen)
          loop self.current() {
            Some(Identifier(col_name)) => {
              self.advance()
              columns.push(col_name)
              if not(self.eat(Token::Comma)) {
                break
              } else {
                continue self.current()
              }
            }
            Some(other) =>
              raise UnexpectedTokenMessageError(
                other, "expected column name in USING clause",
              )
            None => raise ParserError::InternalBug("parse_table_ref")
          }
          self.expect(RParen)
          joins.push({
            join_operator: join_operator_maker(Using(columns)),
            table_ref,
          })
        } else {
          joins.push({ join_operator: join_operator_maker(None), table_ref })
        }
      }
      Some(Keyword(Cross)) =>
        if self.eat_tokens([Keyword(Cross), Keyword(Join)]) {
          let table_ref = self.parse_table_ref()
          joins.push({ join_operator: Cross, table_ref })
        } else {
          raise UnexpectedTokenMessageError(
            self.peek(1).unwrap(),
            "expected 'CROSS JOIN'",
          )
        }
      Some(_other) => break
      None => raise ParserError::InternalBug("parse_table_ref")
    }
  }
  { factor, joins }
}

///|
fn Parser::parse_table_factor(self : Self) -> TableFactor raise ParserError {
  match self.current() {
    Some(Identifier(name)) => {
      self.advance()
      let optional_alias = self.parse_aliasing(
        "expected alias name after table name",
      )
      TableFactor::Column(name, optional_alias)
    }
    Some(Token::LParen) => {
      self.advance()
      let sub_query = self.parse_select_statement()
      self.expect(Token::RParen)
      let optional_alias = self.parse_aliasing(
        "expected alias name after subquery",
      )
      TableFactor::SubQuery(sub_query, optional_alias)
    }
    Some(other) =>
      raise UnexpectedTokenMessageError(
        other, "expected a table name or subquery",
      )
    None => raise ParserError::InternalBug("parse_table_factor")
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
fn Parser::parse_extract_expr(self : Self) -> Expr raise ParserError {
  self.expect(Keyword(Extract))
  self.expect(Token::LParen)
  let field = self.parse_primary_datetime_field()
  self.expect(Keyword(From))
  let expr = self.parse_expr()
  self.expect(Token::RParen)
  Expr::Extract(field, expr)
}

///|
fn Parser::parse_case_expr(self : Self) -> Expr raise ParserError {
  self.expect(Keyword(Case))
  let when_clauses = []
  let mut else_expr : Expr? = None
  let operand : Expr? = if self.current() is Some(Keyword(When)) {
    None
  } else {
    Some(self.parse_expr())
  }
  loop self.current() {
    Some(Keyword(When)) => {
      self.advance()
      let condition = self.parse_expr()
      self.expect(Keyword(Then))
      let result = self.parse_expr()
      when_clauses.push((condition, result))
      continue self.current()
    }
    Some(Keyword(Else)) => {
      self.advance()
      if else_expr is Some(_e) {
        raise MultipleElseInCaseExprError
      }
      else_expr = Some(self.parse_expr())
      continue self.current()
    }
    Some(Keyword(End)) => {
      self.advance()
      break Expr::Case({ when_then_clauses: when_clauses, else_expr, operand })
    }
    Some(other) =>
      raise UnexpectedTokenMessageError(
        other, "expected 'WHEN', 'ELSE', or 'END'",
      )
    None =>
      raise ParserError::InternalBug("parse_case_expr: unexpected end of input")
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
              other,
              "datetime \{keyword} expected a number after '('",
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
fn Parser::parse_between_expr(
  self : Self,
  left : Expr,
  positive : Bool
) -> Expr raise ParserError {
  let low = self.parse_binary_expr(Precedence::Between.value())
  self.expect(Keyword(And))
  let hi = self.parse_binary_expr(Precedence::Between.value())
  Expr::Between(positive~, left, low, hi)
}

///|
fn Parser::parse_in_expr(
  self : Self,
  left : Expr,
  positive : Bool
) -> Expr raise ParserError {
  self.expect(Token::LParen)
  if self.try_parse(fn(p) { p.parse_select_statement() }) is Some(sub_query) {
    self.expect(Token::RParen)
    Expr::InSubQuery(positive~, left, sub_query)
  } else {
    let items = []
    for {
      let item = self.parse_expr()
      items.push(item)
      if self.eat(Token::Comma) {
        continue
      } else {
        self.expect(Token::RParen)
        break Expr::InList(positive~, left, items)
      }
    }
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
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  *
      #|FROM
      #|  t;
    ),
  )
}

///|
test "Parse select with two columns" {
  let input = "SELECT col1, col2 FROM t;"
  let stmt = parse_sql(input)
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  col1,
      #|  col2
      #|FROM
      #|  t;
    ),
  )
}

///|
test "Parse select with function call" {
  let input = "SELECT MAX(arg1, arg2), MIN() as m FROM t;"
  let stmt = parse_sql(input)
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  max(arg1, arg2),
      #|  min() AS m
      #|FROM
      #|  t;
    ),
  )
}

///|
test "Nested expression" {
  let input = "SELECT sum(l_extendedprice * (1 - l_discount)) FROM lineitem;"
  let stmt = parse_sql(input)
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  sum(l_extendedprice * (1 - l_discount))
      #|FROM
      #|  lineitem;
    ),
  )
}

///|
test "Binary expression" {
  let input = "SELECT 1 + 2 * 3 FROM t;"
  let stmt = parse_sql(input)
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  1 + 2 * 3
      #|FROM
      #|  t;
    ),
  )
}

///|
test "Complecated binary expression" {
  let input = "SELECT sum(a * (1 - b) * (2 + b)) AS c FROM t;"
  let stmt = parse_sql(input)
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  sum(a * (1 - b) * (2 + b)) AS c
      #|FROM
      #|  t;
    ),
  )
}

///|
test "Selection clause" {
  let input = "SELECT * FROM t WHERE id = 1;"
  let stmt = parse_sql(input)
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  *
      #|FROM
      #|  t
      #|WHERE
      #|  id = 1;
    ),
  )
}

///|
test "Like, ilike, not like, not ilike" {
  let input = "SELECT * FROM t WHERE name LIKE 'test' AND name ILIKE 'TEST' AND name NOT LIKE 'test2' AND name NOT ILIKE 'TEST2';"
  let stmt = parse_sql(input)
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  *
      #|FROM
      #|  t
      #|WHERE
      #|  name LIKE 'test' 
      #|  AND name ILIKE 'TEST' 
      #|  AND name NOT LIKE 'test2' 
      #|  AND name NOT ILIKE 'TEST2';
    ),
  )
}

///|
test "From multiple table refs" {
  let input = "SELECT * FROM t1, t2;"
  let stmt = parse_sql(input)
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  *
      #|FROM
      #|  t1,
      #|  t2;
    ),
  )
}

///|
test "SubQuery" {
  let input = "SELECT sub FROM (SELECT name FROM users WHERE active = true) AS sub;"
  let stmt = parse_sql(input)
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  sub
      #|FROM
      #|  (
      #|    SELECT
      #|      name
      #|    FROM
      #|      users
      #|    WHERE
      #|      active = TRUE
      #|  ) AS sub;
    ),
  )
}

///|
test "Exists, not exists" {
  let input = "SELECT * FROM t WHERE EXISTS (SELECT 1 FROM t2) AND NOT EXISTS (SELECT 1 FROM t3);"
  let stmt = parse_sql(input)
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  *
      #|FROM
      #|  t
      #|WHERE
      #|  EXISTS (
      #|  SELECT
      #|      1
      #|    FROM
      #|      t2
      #|  ) 
      #|  AND NOT EXISTS (
      #|  SELECT
      #|      1
      #|    FROM
      #|      t3
      #|  );
    ),
  )
}

///|
test "Between and" {
  let input = "SELECT * FROM t WHERE id BETWEEN 1 AND 10;"
  let stmt = parse_sql(input)
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  *
      #|FROM
      #|  t
      #|WHERE
      #|  id BETWEEN 1 AND 10;
    ),
  )
}

///|
test "Compound identifiers" {
  let input = "SELECT t1.col1, t2.col2 FROM t1, t2;"
  let stmt = parse_sql(input)
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  t1.col1,
      #|  t2.col2
      #|FROM
      #|  t1,
      #|  t2;
    ),
  )
}

///|
test "Extract function" {
  let input = "SELECT EXTRACT(YEAR FROM date_col) FROM t;"
  let stmt = parse_sql(input)
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  EXTRACT(YEAR FROM date_col)
      #|FROM
      #|  t;
    ),
  )
}

///|
test "Aliasing omits AS" {
  let input = "SELECT col1 c1, col2 FROM t;"
  let stmt = parse_sql(input)
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  col1 AS c1,
      #|  col2
      #|FROM
      #|  t;
    ),
  )
}

///|
test "Case when" {
  let input = "SELECT CASE WHEN a > 0 THEN 'positive' WHEN a < 0 THEN 'negative' ELSE 'zero' END AS result FROM t;"
  let stmt = parse_sql(input)
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  CASE
      #|    WHEN a > 0 THEN 'positive'
      #|    WHEN a < 0 THEN 'negative'
      #|    ELSE 'zero'
      #|  END AS result
      #|FROM
      #|  t;
    ),
  )
}

///|
test "Having" {
  let input = "SELECT col1, COUNT(*) FROM t GROUP BY col1 HAVING COUNT(*) > 1;"
  let stmt = parse_sql(input)
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  col1,
      #|  count(*)
      #|FROM
      #|  t
      #|GROUP BY
      #|  col1
      #|HAVING
      #|  count(*) > 1;
    ),
  )
}

///|
test "In list" {
  let input = "SELECT * FROM t WHERE col1 IN (1, 2, 3);"
  let stmt = parse_sql(input)
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  *
      #|FROM
      #|  t
      #|WHERE
      #|  col1 IN (1, 2, 3);
    ),
  )
}

///|
test "In subquery" {
  let input = "SELECT * FROM t WHERE col1 IN (SELECT col2 FROM t2);"
  let stmt = parse_sql(input)
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  *
      #|FROM
      #|  t
      #|WHERE
      #|  col1 IN (
      #|    SELECT
      #|      col2
      #|    FROM
      #|      t2
      #|  );
    ),
  )
}

///|
test "Join with ON condition" {
  let input = "SELECT * FROM t1 JOIN t2 ON t1.id = t2.id;"
  let stmt = parse_sql(input)
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  *
      #|FROM
      #|  t1 JOIN t2
      #|    ON t1.id = t2.id;
    ),
  )
}

///|
test "Cross join" {
  let input = "SELECT * FROM t1 CROSS JOIN t2;"
  let stmt = parse_sql(input)
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  *
      #|FROM
      #|  t1 CROSS JOIN t2;
    ),
  )
}

///|
test "Left join" {
  let input = "SELECT * FROM t1 LEFT JOIN t2 ON t1.id = t2.id GROUP BY x;"
  let stmt = parse_sql(input)
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  *
      #|FROM
      #|  t1 LEFT JOIN t2
      #|    ON t1.id = t2.id
      #|GROUP BY
      #|  x;
    ),
  )
}

///|
test "Right join" {
  let input = "SELECT * FROM t1 RIGHT JOIN t2 ON t1.id = t2.id;"
  let stmt = parse_sql(input)
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  *
      #|FROM
      #|  t1 RIGHT JOIN t2
      #|    ON t1.id = t2.id;
    ),
  )
}

///|
test "Full outer join" {
  let input = "SELECT * FROM t1 LEFT OUTER JOIN t2 ON t1.id = t2.id;"
  let stmt = parse_sql(input)
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  *
      #|FROM
      #|  t1 LEFT OUTER JOIN t2
      #|    ON t1.id = t2.id;
    ),
  )
}

///|
test "Null, true and false" {
  let input = "SELECT NULL, true, false FROM t1;"
  let stmt = parse_sql(input)
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  NULL,
      #|  TRUE,
      #|  FALSE
      #|FROM
      #|  t1;
    ),
  )
}

///|
test "Unary plus and minus" {
  let input = "SELECT +1, -2 FROM t;"
  let stmt = parse_sql(input)
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  +1,
      #|  +2
      #|FROM
      #|  t;
    ),
  )
}

///|
test "Unary not expression" {
  let input = "SELECT NOT a FROM t;"
  let stmt = parse_sql(input)
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  NOT a
      #|FROM
      #|  t;
    ),
  )
}

///|
test "Using clause in join" {
  let input = "SELECT * FROM t1 JOIN t2 USING (id);"
  let stmt = parse_sql(input)
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  *
      #|FROM
      #|  t1 JOIN t2
      #|    USING (id);
    ),
  )
}
