///|
pub struct MySQL {}

///|
impl Dialect for MySQL with supports_string_literal_backslash_escape(_self) {
  true
}

///|
impl Dialect for MySQL with supports_boolean_literals(_self) {
  false
}

///|
impl Dialect for MySQL with supports_filter_during_aggregation(_self) {
  false
}

///|
impl Dialect for MySQL with supports_double_quoted_identifiers(_self) {
  false
}

///|
impl Dialect for MySQL with supports_if_not_exists(_self) {
  true
}

///|
impl Dialect for MySQL with parse_statement(
  _self : MySQL,
  _parser : Parser,
  _tokens : ArrayView[Token],
) -> ParserResult[Statement]? raise ParserError {
  match _tokens {
    [Keyword(Show), .. _rest] => {
      let (stmt, remaining_tokens) = parse_mysql_show_statement(_parser, _rest)
      Some((Statement::Show(stmt), remaining_tokens))
    }
    _ => None
  }
}

///|
/// MySQL-specific SHOW statement parsing
fn parse_mysql_show_statement(
  parser : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[ShowStmt] raise ParserError {
  // Note: The SHOW token has already been consumed by the caller
  
  let (show_type, remaining_tokens) = match tokens {
    [Keyword(Tables), .. rest] => (ShowType::Tables, rest)
    [Keyword(Columns), .. rest] => (ShowType::Columns, rest)
    [Keyword(Status), .. rest] => (ShowType::Status, rest)
    [Keyword(Databases), .. rest] => (ShowType::Databases, rest)
    [token, .. _rest] =>
      raise UnexpectedTokenMessageError(token, "expected TABLES, COLUMNS, STATUS, or DATABASES")
    [] => raise InternalBug("parse_mysql_show_statement: unexpected end of tokens")
  }
  
  // Parse optional FROM clause
  let (object, remaining_tokens2) = match remaining_tokens {
    [Keyword(From), .. rest] => {
      let (obj_name, final_tokens) = parser.parse_object_name(rest)
      (Some(obj_name), final_tokens)
    }
    _ => (None, remaining_tokens)
  }
  
  // Parse optional filter (LIKE or WHERE)
  let (filter, final_tokens) = match remaining_tokens2 {
    [Keyword(Like), StringLiteral(pattern), .. rest] =>
      (Some(ShowFilter::Like(pattern)), rest)
    [Keyword(Where), .. rest] => {
      let (expr, final_tokens) = parser.parse_expr(rest)
      (Some(ShowFilter::Where(expr)), final_tokens)
    }
    _ => (None, remaining_tokens2)
  }
  
  ({ show_type, object, filter, }, final_tokens)
}

///|
test "MySQL trait object dispatch test" {
  // Test if trait object dispatch works
  let mysql_dialect = MySQL::{}
  let dialect_ref : &Dialect = mysql_dialect
  let parser = Parser::{ dialect: dialect_ref }
  let tokens_arr = [Keyword(Show), Keyword(Tables), Semicolon]
  let tokens_view = tokens_arr[:]
  
  let result = dialect_ref.parse_statement(parser, tokens_view)
  match result {
    Some((stmt, remaining_tokens)) => {
      let _ = stmt  // Just use the parsed statement
      let _ = remaining_tokens  // Just use the remaining tokens
    }
    None => inspect("None", content="Trait object test: parse_statement returned None")
  }
}

test "MySQL SUPER SIMPLE test" {
  // Simplest possible test
  let mysql_dialect = MySQL::{}
  let tokens_arr = [Keyword(Show), Keyword(Tables), Semicolon]
  
  // This should work if everything is correct
  let parse_result = parse(dialect=mysql_dialect, tokens_arr[:])
  inspect(parse_result.length(), content="Super simple test: statement count")
}

test "MySQL SHOW TABLES" {
  let tokens = "SHOW TABLES;"
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
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
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
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
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
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
  let stmt = parse_sql(dialect=MySQL::{}, tokens).stmts[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SHOW COLUMNS FROM `table name`;
    ),
  )
}
