///|
suberror ParserError {
  UnexpectedTokenError(Token, Token)
  UnexpectedTokenMessageError(Token, String)
  MultipleElseInCaseExprError
  UnimplementedError(String)
  InternalBug(String)
  InvalidDataTypeError(String)
} derive(Show)

///|
typealias (T, ArrayView[Token]) as ParserResult[T]

///|
priv struct Parser {
  dialect : &Dialect
  // recursion counter
}

///|
fn[T, U] ParserResult::map(
  self : ParserResult[T],
  f : (T) -> U,
) -> ParserResult[U] {
  let (result, tokens) = self
  (f(result), tokens)
}

///|
fn Parser::expect_token(
  _self : Parser,
  tokens : ArrayView[Token],
  expected : Token,
) -> ArrayView[Token] raise ParserError {
  match tokens {
    [token, .. tokens] if token == expected => tokens
    [token, .. _tokens] => raise UnexpectedTokenError(token, expected)
    [] => raise UnexpectedTokenError(Token::Eof, expected)
  }
}

///|
pub fn parse(
  dialect~ : &Dialect = MySQL::{  },
  tokens : ArrayView[Token],
) -> Array[Statement] raise ParserError {
  let parser = Parser::{ dialect, }
  let statements = []
  loop tokens {
    [Token::Eof] => break
    [] => break
    tokens => {
      let (stmt, tokens) = parser.parse_statement(tokens)
      statements.push(stmt)
      continue tokens
    }
  }
  statements
}

///|
fn Parser::parse_statement(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[Statement] raise ParserError {
  let (stmt, tokens) = match tokens {
    [Keyword(Select), .. _rest] =>
      self.parse_query(tokens).map(Statement::Query(_))
    [Keyword(Create), Keyword(Table), .. _rest] =>
      self.parse_create_table_statement(tokens).map(Statement::CreateTable(_))
    [Keyword(Create), Keyword(View), .. _rest] =>
      self.parse_create_view_statement(tokens).map(Statement::CreateView(_))
    [Keyword(Drop), Keyword(View), .. _rest] =>
      self.parse_drop_view_statement(tokens).map(Statement::DropView(_))
    [Keyword(Drop), Keyword(Table), .. _rest] =>
      self.parse_drop_table_statement(tokens).map(Statement::DropTable(_))
    [Keyword(Insert), .. _rest] =>
      self.parse_insert_statement(tokens).map(Statement::Insert(_))
    [Keyword(Delete), .. _rest] =>
      self.parse_delete_statement(tokens).map(Statement::Delete(_))
    [Keyword(Update), .. _rest] =>
      self.parse_update_statement(tokens).map(Statement::Update(_))
    [Keyword(Truncate), .. _rest] =>
      self.parse_truncate_statement(tokens).map(Statement::Truncate(_))
    [LParen, .. rest] => {
      let (stmt, tokens) = self.parse_statement(rest)
      let tokens = self.expect_token(tokens, RParen)
      (stmt, tokens)
    }
    _ => raise UnexpectedTokenError(tokens[0], Keyword(Select))
  }
  let tokens = if tokens is [Semicolon, .. tokens] { tokens } else { tokens }
  (stmt, tokens)
}

///|
test "Parse simple select statement" {
  let tokens = [
    Keyword(Select),
    Token::Mul,
    Keyword(From),
    Token::Identifier("t"),
    Token::Semicolon,
  ]
  let stmt = parse(tokens)[0] |> pretty_print
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
