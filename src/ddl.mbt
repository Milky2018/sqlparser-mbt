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
    [Keyword(Int), .. tokens] => (Integer, tokens)
    [Keyword(Float), LParen, Number(n), RParen, .. tokens] => {
      let n = @strconv.parse_int(n) catch {
        _ => raise ParserError::InvalidDataTypeError(n)
      }
      (Float(Some(n)), tokens)
    }
    [Keyword(Float), .. tokens] => (Float(None), tokens)
    [Keyword(Real), .. tokens] => (Real, tokens)
    [Keyword(Double), .. tokens] => (Double, tokens)
    [Keyword(Char), LParen, Number(n), RParen, .. tokens] => {
      let n = @strconv.parse_int(n) catch {
        _ => raise ParserError::InvalidDataTypeError(n)
      }
      (Char(n), tokens)
    }
    [Keyword(Varchar), LParen, Number(n), RParen, .. tokens] => {
      let n = @strconv.parse_int(n) catch {
        _ => raise ParserError::InvalidDataTypeError(n)
      }
      (Varchar(n), tokens)
    }
    [Keyword(Text), .. tokens] => (Text, tokens)
    [Keyword(Boolean), .. tokens] => (Boolean, tokens)
    [Keyword(Timestamp), .. tokens] => (Timestamp, tokens)
    [Keyword(Blob), .. tokens] => (Blob, tokens)
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

///|
test "Many kinds of data types" {
  let tokens =
    #|CREATE TABLE users (
    #|  id INTEGER,
    #|  name VARCHAR(100),
    #|  age INT,
    #|  active BOOLEAN,
    #|  balance FLOAT(2),
    #|  created_at TIMESTAMP,
    #|  updated_at TIMESTAMP,
    #|  description TEXT,
    #|  profile_picture BLOB
    #|);
  let stmt = parse_sql(tokens)[0]
  inspect(
    stmt,
    content=(
      #|CREATE TABLE users (
      #|  id INTEGER, 
      #|  name VARCHAR(100), 
      #|  age INTEGER, 
      #|  active BOOLEAN, 
      #|  balance FLOAT(2), 
      #|  created_at TIMESTAMP, 
      #|  updated_at TIMESTAMP, 
      #|  description TEXT, 
      #|  profile_picture BLOB
      #|);
    ),
  )
}
