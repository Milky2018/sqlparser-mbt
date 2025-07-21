///|
fn parse_create_table_statement(
  tokens : ArrayView[Token]
) -> Parser[CreateTableStmt] raise ParserError {
  let tokens = expect_token(tokens, Keyword(Create))
  let tokens = expect_token(tokens, Keyword(Table))
  match tokens {
    [Token::Identifier(name), .. tokens] => {
      let (columns, tokens) = parse_column_defs(tokens)
      ({ name, columns, primary_key: None }, tokens)
    }
    _ =>
      raise UnexpectedTokenError(
        tokens[0],
        Token::Identifier("table_name".to_string()),
      )
  }
}

///|
test "Create table" {
  let tokens = "CREATE TABLE users;"
  let stmt = parse_sql(tokens)[0]
  inspect(stmt, content="CREATE TABLE users();")
}

///|
fn parse_column_defs(
  tokens : ArrayView[Token]
) -> Parser[Array[ColumnDef]] raise ParserError {
  let columns = []
  let tokens = if tokens is [Token::LParen, .. tokens] {
    loop tokens {
      [Identifier(name), .. tokens] => {
        let (data_type, tokens) = parse_data_type(tokens)
        columns.push({ name, data_type })
        // let (option, tokens) = try parse_column_option() {} noraise {}
        match tokens {
          [Comma, .. tokens] => continue tokens
          [RParen, .. tokens] => break tokens
          [token, ..] =>
            raise UnexpectedTokenMessageError(
              token, "expected ',' or ')', found",
            )
          [] => raise InternalBug("parse_column_defs: unexpected end of tokens")
        }
        continue tokens
      }
      [token, .. _tokens] =>
        raise UnexpectedTokenMessageError(token, "expected column definition")
      [] => raise InternalBug("parse_column_defs: unexpected end of tokens")
    }
  } else {
    tokens
  }
  (columns, tokens)
}

///|
fn parse_data_type(
  tokens : ArrayView[Token]
) -> Parser[DataType] raise ParserError {
  match tokens {
    [Keyword(Integer), .. tokens] => (Integer, tokens)
    [token, .. _tokens] =>
      raise UnexpectedTokenMessageError(token, "expected data type")
    [] => raise InternalBug("parse_data_type: unexpected end of tokens")
  }
}

///|
test "Create table with two columns" {
  let tokens = "CREATE TABLE users (id INTEGER, name INTEGER);"
  let stmt = parse_sql(tokens)[0]
  inspect(
    stmt,
    content=(
      #|CREATE TABLE users (
      #|  id INTEGER, 
      #|  name INTEGER
      #|);
    ),
  )
}
