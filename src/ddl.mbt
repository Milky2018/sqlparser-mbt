///|
fn Parser::parse_create_table_statement(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[CreateTableStmt] raise ParserError {
  let tokens = self.expect_token(tokens, Keyword(Create))
  let tokens = self.expect_token(tokens, Keyword(Table))
  
  // Parse optional IF NOT EXISTS
  let (if_not_exists, tokens) = match tokens {
    [Keyword(If), Keyword(Not), Keyword(Exists), .. tokens] => (true, tokens)
    _ => (false, tokens)
  }
  
  match tokens {
    [Token::Identifier(name), .. tokens] => {
      let ((columns, constraints), tokens) = self.parse_column_defs(tokens)
      ({ name, if_not_exists, columns, constraints }, tokens)
    }
    [Token::StringLiteral(name), .. tokens] => {
      let ((columns, constraints), tokens) = self.parse_column_defs(tokens)
      ({ name, if_not_exists, columns, constraints }, tokens)
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
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE TABLE users (
      #|  
      #|);
    ),
  )
}

///|
test "Create table IF NOT EXISTS" {
  let tokens = "CREATE TABLE IF NOT EXISTS users (id INTEGER);"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE TABLE IF NOT EXISTS users (
      #|  id INTEGER
      #|);
    ),
  )
}

///|
fn Parser::parse_column_defs(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[(Array[ColumnDef], Array[TableConstraint])] raise ParserError {
  let columns = []
  let constraints = []
  let tokens = if tokens is [Token::LParen, .. tokens] {
    loop tokens {
      [Identifier(name), .. tokens] => {
        let (data_type, tokens) = self.parse_data_type(tokens)
        let (options, tokens) = self.parse_column_def_option(tokens)
        columns.push({ name, data_type, options })
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
      tokens => {
        let (constraint, tokens) = self.parse_table_constraint(tokens)
        constraints.push(constraint)
        match tokens {
          [Comma, .. tokens] => continue tokens
          [RParen, .. tokens] => break tokens
          [token, .. _tokens] =>
            raise UnexpectedTokenMessageError(
              token, "expected ',' or ')', found",
            )
          [] => raise InternalBug("parse_column_defs: unexpected end of tokens")
        }
      }
    }
  } else {
    tokens
  }
  ((columns, constraints), tokens)
}

///|
fn Parser::parse_data_type(
  _self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[DataType] raise ParserError {
  match tokens {
    [Keyword(Integer) | Keyword(Int), .. tokens] => (Integer, tokens)
    [Keyword(Smallint), .. tokens] => (Smallint, tokens)
    [Keyword(Bigint), .. tokens] => (Bigint, tokens)
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
  let stmt = parse_sql(tokens)[0] |> pretty_print
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
  let stmt = parse_sql(tokens)[0] |> pretty_print
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

///|
fn Parser::parse_column_def_option(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[Array[ColumnDefOption]] raise ParserError {
  let options = []
  let tokens = loop tokens {
    [Keyword(Primary), Keyword(Key), .. tokens] => {
      options.push(ColumnDefOption::PrimaryKey)
      continue tokens
    }
    [Keyword(Unique), .. tokens] => {
      options.push(ColumnDefOption::Unique)
      continue tokens
    }
    [Keyword(Not), Keyword(Null), .. tokens] => {
      options.push(NotNull)
      continue tokens
    }
    [Keyword(Default), .. tokens] => {
      let (expr, tokens) = self.parse_expr(tokens)
      options.push(Default(expr))
      continue tokens
    }
    tokens => break tokens
  }
  (options, tokens)
}

///|
test "With options" {
  let tokens = "CREATE TABLE users (id INTEGER NOT NULL UNIQUE, name INTEGER DEFAULT 18);"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE TABLE users (
      #|  id INTEGER NOT NULL UNIQUE, 
      #|  name INTEGER DEFAULT 18
      #|);
    ),
  )
}

///|
fn Parser::parse_create_view_statement(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[CreateViewStmt] raise ParserError {
  let tokens = self.expect_token(tokens, Keyword(Create))
  let tokens = self.expect_token(tokens, Keyword(View))
  guard tokens is [Identifier(name), .. tokens] else {
    raise UnexpectedTokenError(
      tokens[0],
      Token::Identifier("view_name".to_string()),
    )
  }
  let columns = []
  let tokens = if tokens is [LParen, .. tokens] {
    loop tokens {
      tokens => {
        let (column, tokens) = self.parse_view_column_def(tokens)
        columns.push(column)
        match tokens {
          [Comma, .. tokens] => continue tokens
          [RParen, .. tokens] => break tokens
          [token, .. _tokens] =>
            raise UnexpectedTokenMessageError(
              token, "expected ',' or ')', found",
            )
          [] =>
            raise InternalBug(
              "parse_create_view_statement: unexpected end of tokens",
            )
        }
      }
    }
  } else {
    tokens
  }
  let tokens = self.expect_token(tokens, Keyword(As))
  let (query, tokens) = self.parse_query(tokens)
  ({ name, columns, query }, tokens)
}

///|
fn Parser::parse_view_column_def(
  _self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[ViewColumnDef] raise ParserError {
  match tokens {
    [Identifier(name), .. tokens] => ({ name, }, tokens)
    [token, .. _tokens] =>
      raise UnexpectedTokenMessageError(token, "expected column definition")
    [] => raise InternalBug("parse_view_column_def: unexpected end of tokens")
  }
}

///|
test "Create view with columns" {
  let tokens = "CREATE VIEW user_view (id, name) AS SELECT id, name FROM users;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE VIEW user_view (id, name) AS
      #|SELECT
      #|  id,
      #|  name
      #|FROM
      #|  users;
    ),
  )
}

///|
fn Parser::parse_drop_view_statement(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[DropViewStmt] raise ParserError {
  let tokens = self.expect_token(tokens, Keyword(Drop))
  let tokens = self.expect_token(tokens, Keyword(View))
  guard tokens is [Identifier(name), .. tokens] else {
    raise UnexpectedTokenError(
      tokens[0],
      Token::Identifier("view_name".to_string()),
    )
  }
  (DropViewStmt::{ name, }, tokens)
}

///|
test "Drop view statement" {
  let tokens = "DROP VIEW user_view;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|DROP VIEW user_view;
    ),
  )
}

///|
fn Parser::parse_table_constraint(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[TableConstraint] raise ParserError {
  match tokens {
    [Keyword(Primary), Keyword(Key), LParen, .. tokens] => {
      let (columns, tokens) = self.parse_order_by(tokens)
      let tokens = self.expect_token(tokens, RParen)
      (TableConstraint::PrimaryKey(columns), tokens)
    }
    [Keyword(Unique), LParen, .. tokens] => {
      let (columns, tokens) = self.parse_order_by(tokens)
      let tokens = self.expect_token(tokens, RParen)
      (TableConstraint::Unique(columns), tokens)
    }
    [Keyword(Foreign), Keyword(Key), LParen, ..] as tokens =>
      self.parse_foreign_key_constraint(tokens)
    [Keyword(Check), LParen, .. tokens] => {
      let (expr, tokens) = self.parse_expr(tokens)
      let tokens = self.expect_token(tokens, RParen)
      (TableConstraint::Check(expr), tokens)
    }
    [token, .. _tokens] =>
      raise UnexpectedTokenMessageError(token, "expected table constraint")
    [] => raise InternalBug("parse_table_constraint: unexpected end of tokens")
  }
}

///|
test "Table constraints" {
  let tokens =
    #|CREATE TABLE users (
    #|  id INTEGER PRIMARY KEY,
    #|  name VARCHAR(100) UNIQUE,
    #|  age INTEGER,
    #|  PRIMARY KEY (id, name),
    #|  UNIQUE (name)
    #|);
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE TABLE users (
      #|  id INTEGER PRIMARY KEY, 
      #|  name VARCHAR(100) UNIQUE, 
      #|  age INTEGER, 
      #|  PRIMARY KEY (id, name), 
      #|  UNIQUE (name)
      #|);
    ),
  )
}

///|
fn Parser::parse_foreign_key_constraint(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[TableConstraint] raise ParserError {
  let tokens = self.expect_token(tokens, Keyword(Foreign))
  let tokens = self.expect_token(tokens, Keyword(Key))
  guard tokens is [LParen, .. tokens] else {
    raise UnexpectedTokenError(tokens[0], Token::LParen)
  }
  let (columns, tokens) = self.parse_order_by(tokens)
  let tokens = self.expect_token(tokens, RParen)
  let tokens = self.expect_token(tokens, Keyword(References))
  let (foreign_table, tokens) = self.parse_object_name(tokens)
  let foreign_columns = []
  let tokens = if tokens is [LParen, .. tokens] {
    loop tokens {
      [Identifier(col), Comma, .. tokens] => {
        foreign_columns.push(col)
        continue tokens
      }
      [Identifier(col), RParen, .. tokens] => {
        foreign_columns.push(col)
        break tokens
      }
      [token, .. _tokens] =>
        raise UnexpectedTokenMessageError(
          token, "expected foreign key column definition",
        )
      [] =>
        raise InternalBug(
          "parse_foreign_key_constraint: unexpected end of tokens",
        )
    }
  } else {
    tokens
  }
  (ForeignKey(foreign_columns~, foreign_table~, columns~), tokens)
}

///|
test "Foreign key" {
  let tokens =
    #|CREATE TABLE users (
    #|  id INTEGER PRIMARY KEY,
    #|  name VARCHAR(100) UNIQUE,
    #|  FOREIGN KEY (id) REFERENCES other_table (other_id)
    #|);
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE TABLE users (
      #|  id INTEGER PRIMARY KEY, 
      #|  name VARCHAR(100) UNIQUE, 
      #|  FOREIGN KEY (id) REFERENCES other_table (other_id)
      #|);
    ),
  )
}

///|
test "Foreign key without columns" {
  let tokens =
    #|CREATE TABLE users (
    #|  id INTEGER PRIMARY KEY,
    #|  name VARCHAR(100) UNIQUE,
    #|  FOREIGN KEY (name) REFERENCES other_table
    #|);
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE TABLE users (
      #|  id INTEGER PRIMARY KEY, 
      #|  name VARCHAR(100) UNIQUE, 
      #|  FOREIGN KEY (name) REFERENCES other_table
      #|);
    ),
  )
}

///|
test "Check" {
  let tokens =
    #|CREATE TABLE users (
    #|  id INTEGER PRIMARY KEY,
    #|  name VARCHAR(100) UNIQUE,
    #|  CHECK (id > 0)
    #|);
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE TABLE users (
      #|  id INTEGER PRIMARY KEY, 
      #|  name VARCHAR(100) UNIQUE, 
      #|  CHECK (id > 0)
      #|);
    ),
  )
}
