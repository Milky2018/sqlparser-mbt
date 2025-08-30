///|
/// MySQL-specific parsing functions

///|
fn Parser::parse_mysql_show_statement(
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
    [] => raise InternalBug("parse_mysql_show_statement: unexpected end of tokens")
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

///|
test "MySQL SHOW TABLES" {
  let tokens = "SHOW TABLES;"
  let stmt = parse_sql(dialect=MySQL::{}, tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SHOW TABLES;
    ),
  )
}

///|
test "MySQL SHOW COLUMNS FROM table" {
  let tokens = "SHOW COLUMNS FROM users;"
  let stmt = parse_sql(dialect=MySQL::{}, tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SHOW COLUMNS FROM users;
    ),
  )
}

///|
test "MySQL SHOW TABLES LIKE pattern" {
  let tokens = "SHOW TABLES LIKE 'user%';"
  let stmt = parse_sql(dialect=MySQL::{}, tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SHOW TABLES LIKE 'user%';
    ),
  )
}

///|
test "MySQL with backticks in SHOW" {
  let tokens = "SHOW COLUMNS FROM `table name`;"
  let stmt = parse_sql(dialect=MySQL::{}, tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SHOW COLUMNS FROM `table name`;
    ),
  )
}