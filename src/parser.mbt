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
pub struct Parser {
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
  // Try dialect-specific parsing first
  let dialect_result = self.dialect.parse_statement(self, tokens)
  match dialect_result {
    Some(result) => return result
    None => ()
  }
  
  let (stmt, tokens) = match tokens {
    [Keyword(Select), .. _rest] =>
      self.parse_query(tokens).map(Statement::Query(_))
    [Keyword(Show), .. _rest] =>
      self.parse_show_statement(tokens).map(Statement::Show(_))
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
    [Keyword(Alter), Keyword(Table), .. _rest] =>
      self.parse_alter_table_statement(tokens).map(Statement::AlterTable(_))
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
///|
fn Parser::parse_show_statement(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[ShowStmt] raise ParserError {
  let tokens = self.expect_token(tokens, Keyword(Show))
  
  let (show_type, tokens) = match tokens {
    [Keyword(Tables), .. tokens] => (ShowType::Tables, tokens)
    [Keyword(Columns), .. tokens] => (ShowType::Columns, tokens)
    [Keyword(Status), .. tokens] => (ShowType::Status, tokens)
    [Keyword(Databases), .. tokens] => (ShowType::Databases, tokens)
    [token, .. _tokens] =>
      raise UnexpectedTokenMessageError(token, "expected TABLES, COLUMNS, STATUS, or DATABASES")
    [] => raise InternalBug("parse_show_statement: unexpected end of tokens")
  }
  
  // Parse optional FROM clause
  let (object, tokens) = match tokens {
    [Keyword(From), .. tokens] => {
      let (obj_name, tokens) = self.parse_object_name(tokens)
      (Some(obj_name), tokens)
    }
    _ => (None, tokens)
  }
  
  // Parse optional filter (LIKE or WHERE)
  let (filter, tokens) = match tokens {
    [Keyword(Like), StringLiteral(pattern), .. tokens] =>
      (Some(ShowFilter::Like(pattern)), tokens)
    [Keyword(Where), .. tokens] => {
      let (expr, tokens) = self.parse_expr(tokens)
      (Some(ShowFilter::Where(expr)), tokens)
    }
    _ => (None, tokens)
  }
  
  ({ show_type, object, filter, }, tokens)
}

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
