///|
suberror ParserError {
  UnexpectedTokenError(Token, Token)
  UnexpectedTokenMessageError(Token, String)
  MultipleElseInCaseExprError
  UnimplementedError(String)
  InternalBug(String)
} derive(Show)

///|
typealias (T, ArrayView[Token]) as Parser[T]

///|
fn[T, U] Parser::map(self : Parser[T], f : (T) -> U) -> Parser[U] {
  let (result, tokens) = self
  (f(result), tokens)
}

///|
fn[T, U] Parser::bind(self : Parser[T], f : (T) -> Parser[U]) -> Parser[U] {
  let (result, _tokens) = self
  let (next_result, next_tokens) = f(result)
  (next_result, next_tokens)
}

///|
fn expect_token(
  tokens : ArrayView[Token],
  expected : Token
) -> ArrayView[Token] raise ParserError {
  guard tokens is [token, .. tokens] && expected == token else {
    raise UnexpectedTokenError(tokens[0], expected)
  }
  tokens
}

///|
pub fn parse(tokens : ArrayView[Token]) -> Array[Statement] raise ParserError {
  let statements = []
  loop tokens {
    [Token::Eof] => break
    [] => break
    tokens => {
      let (stmt, tokens) = parse_statement(tokens)
      statements.push(stmt)
      continue tokens
    }
  }
  statements
}

///|
fn parse_statement(
  tokens : ArrayView[Token]
) -> Parser[Statement] raise ParserError {
  let (stmt, tokens) = match tokens {
    [Keyword(Select), .. _rest] =>
      parse_select_statement(tokens).map(Statement::Select(_))
    [Keyword(Create), Keyword(Table), .. _rest] =>
      parse_create_table_statement(tokens).map(Statement::CreateTable(_))
    _ => raise UnexpectedTokenError(tokens[0], Keyword(Select))
  }
  let tokens = expect_token(tokens, Semicolon)
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
  let stmt = parse(tokens)[0]
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
