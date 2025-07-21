///|
fn parse_create_table_statement(
  tokens : ArrayView[Token]
) -> Parser[CreateTableStmt] raise ParserError {
  let tokens = expect_token(tokens, Keyword(Create))
  let tokens = expect_token(tokens, Keyword(Table))
  match tokens {
    [Token::Identifier(name), .. tokens] => ({ name, columns: [], primary_key:None }, tokens)
    _ =>
      raise UnexpectedTokenError(
        tokens[0],
        Token::Identifier("table_name".to_string()),
      )
  }
}

test "Create table" {
  let tokens = "CREATE TABLE users;"
  let stmt = parse_sql(tokens)[0]
  inspect(stmt, content="CREATE TABLE users();")
}