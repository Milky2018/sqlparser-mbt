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
  let (name, tokens) = match tokens {
    [Token::Identifier(name), .. tokens] => (name, tokens)
    [Token::StringLiteral(name), .. tokens] => (name, tokens)
    _ =>
      raise UnexpectedTokenError(
        tokens[0],
        Token::Identifier("table_name".to_string()),
      )
  }

  // Parse table definition - either columns or AS SELECT
  let (definition, tokens) = match tokens {
    [Keyword(As), .. tokens] => {
      let (query, tokens) = self.parse_query(tokens)
      (CreateTableDefinition::AsQuery(query), tokens)
    }
    _ => {
      let ((columns, constraints), tokens) = self.parse_column_defs(tokens)
      (CreateTableDefinition::Columns(columns, constraints), tokens)
    }
  }
  ({ name, if_not_exists, definition }, tokens)
}

///|
/// Parse CREATE INDEX statement
fn Parser::parse_create_index_statement(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[CreateIndexStmt] raise ParserError {
  let tokens = self.expect_token(tokens, Keyword(Create))

  // Parse optional UNIQUE
  let (unique, tokens) = match tokens {
    [Keyword(Unique), .. tokens] => (true, tokens)
    _ => (false, tokens)
  }
  let tokens = self.expect_token(tokens, Keyword(Index))

  // Parse optional CONCURRENTLY
  let (concurrently, tokens) = match tokens {
    [Keyword(Concurrently), .. tokens] => (true, tokens)
    _ => (false, tokens)
  }

  // Parse optional IF NOT EXISTS
  let (if_not_exists, tokens) = match tokens {
    [Keyword(If), Keyword(Not), Keyword(Exists), .. tokens] => (true, tokens)
    _ => (false, tokens)
  }

  // Parse index name
  let (name, tokens) = match tokens {
    [Token::Identifier(name), .. tokens] => (name, tokens)
    [Token::StringLiteral(name), .. tokens] => (name, tokens)
    [token, ..] =>
      raise UnexpectedTokenError(
        token,
        Token::Identifier("index_name".to_string()),
      )
    [] =>
      raise ParserError::InternalBug(
        "parse_create_index_statement: unexpected end of tokens",
      )
  }

  // Parse ON table_name
  let tokens = self.expect_token(tokens, Keyword(On))
  let (table_name, tokens) = self.parse_object_name(tokens)

  // Parse optional USING method
  let (index_method, tokens) = match tokens {
    [Keyword(Using), Keyword(Btree), .. tokens] =>
      (Some(IndexMethod::Btree), tokens)
    [Keyword(Using), Keyword(Hash), .. tokens] =>
      (Some(IndexMethod::Hash), tokens)
    [Keyword(Using), Keyword(Gin), .. tokens] =>
      (Some(IndexMethod::Gin), tokens)
    [Keyword(Using), Keyword(Gist), .. tokens] =>
      (Some(IndexMethod::Gist), tokens)
    [Keyword(Using), Keyword(Spgist), .. tokens] =>
      (Some(IndexMethod::Spgist), tokens)
    [Keyword(Using), Keyword(Brin), .. tokens] =>
      (Some(IndexMethod::Brin), tokens)
    _ => (None, tokens)
  }

  // Parse column list
  let tokens = self.expect_token(tokens, LParen)
  let columns = []
  let tokens = loop tokens {
    [RParen, .. rest_tokens] => break rest_tokens
    rest_tokens => {
      let (column_expr, rest_tokens) = self.parse_expr(rest_tokens)

      // Parse optional ASC/DESC
      let (asc, rest_tokens) = match rest_tokens {
        [Keyword(Asc), .. rest_tokens] => (Some(true), rest_tokens)
        [Keyword(Desc), .. rest_tokens] => (Some(false), rest_tokens)
        _ => (None, rest_tokens)
      }

      // Parse optional NULLS FIRST/LAST
      let (nulls_first, rest_tokens) = match rest_tokens {
        [Keyword(Nulls), Keyword(First), .. rest_tokens] =>
          (Some(true), rest_tokens)
        [Keyword(Nulls), Keyword(Last), .. rest_tokens] =>
          (Some(false), rest_tokens)
        _ => (None, rest_tokens)
      }
      columns.push({ name: column_expr, asc, nulls_first })
      match rest_tokens {
        [Comma, .. rest_tokens] => continue rest_tokens
        [RParen, .. rest_tokens] => break rest_tokens
        [token, ..] => raise UnexpectedTokenError(token, RParen)
        [] =>
          raise ParserError::InternalBug(
            "parse_create_index_statement: unexpected end of tokens",
          )
      }
    }
  }

  // Parse optional WHERE clause
  let (where_clause, tokens) = match tokens {
    [Keyword(Where), .. tokens] => {
      let (expr, tokens) = self.parse_expr(tokens)
      (Some(expr), tokens)
    }
    _ => (None, tokens)
  }
  (
    {
      unique,
      concurrently,
      if_not_exists,
      name,
      table_name,
      index_method,
      columns,
      where_clause,
    },
    tokens,
  )
}

///|
/// CREATE INDEX Tests
test "CREATE INDEX - Simple" {
  let tokens = "CREATE INDEX idx_name ON users (email);"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE INDEX idx_name ON users (email);
    ),
  )
}

///|
test "CREATE UNIQUE INDEX" {
  let tokens = "CREATE UNIQUE INDEX idx_unique_email ON users (email);"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE UNIQUE INDEX idx_unique_email ON users (email);
    ),
  )
}

///|
test "CREATE INDEX with multiple columns" {
  let tokens = "CREATE INDEX idx_name_age ON users (name, age DESC);"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE INDEX idx_name_age ON users (name, age DESC);
    ),
  )
}

///|
test "CREATE INDEX with USING method" {
  let tokens = "CREATE INDEX idx_hash ON users USING HASH (id);"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE INDEX idx_hash ON users USING HASH (id);
    ),
  )
}

///|
test "CREATE INDEX with WHERE clause" {
  let tokens = "CREATE INDEX idx_active_users ON users (created_at) WHERE active = true;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE INDEX idx_active_users ON users (created_at) WHERE active = TRUE;
    ),
  )
}

///|
test "CREATE INDEX CONCURRENTLY" {
  let tokens = "CREATE INDEX CONCURRENTLY idx_concurrent ON users (email);"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE INDEX CONCURRENTLY idx_concurrent ON users (email);
    ),
  )
}

///|
test "CREATE INDEX IF NOT EXISTS" {
  let tokens = "CREATE INDEX IF NOT EXISTS idx_exists ON users (email);"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE INDEX IF NOT EXISTS idx_exists ON users (email);
    ),
  )
}

///|
test "CREATE INDEX with NULLS ordering" {
  let tokens = "CREATE INDEX idx_ordered ON users (name ASC NULLS FIRST, age DESC NULLS LAST);"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE INDEX idx_ordered ON users (name ASC NULLS FIRST, age DESC NULLS LAST);
    ),
  )
}

///|
test "CREATE INDEX with expression" {
  let tokens = "CREATE INDEX idx_lower_email ON users (LOWER(email));"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE INDEX idx_lower_email ON users (lower(email));
    ),
  )
}

///|
test "CREATE UNIQUE INDEX with all options" {
  let tokens = "CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS idx_complex ON users USING BTREE (email ASC NULLS FIRST, created_at DESC) WHERE active = true;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS idx_complex ON users USING BTREE (email ASC NULLS FIRST, created_at DESC) WHERE active = TRUE;
    ),
  )
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
test "Create table AS SELECT" {
  let tokens = "CREATE TABLE students_2 AS SELECT * FROM students;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE TABLE students_2 AS SELECT
      #|  *
      #|FROM
      #|  students;
    ),
  )
}

///|
test "Create table AS SELECT with WHERE" {
  let tokens = "CREATE TABLE students_3 AS SELECT city, grade FROM students WHERE grade > 3.0;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE TABLE students_3 AS SELECT
      #|  city,
      #|  grade
      #|FROM
      #|  students
      #|WHERE
      #|  grade > 3;
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

///|
fn Parser::parse_drop_table_statement(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[DropTableStmt] raise ParserError {
  let tokens = self.expect_token(tokens, Keyword(Drop))
  let tokens = self.expect_token(tokens, Keyword(Table))

  // Parse optional IF EXISTS
  let (if_exists, tokens) = match tokens {
    [Keyword(If), Keyword(Exists), .. tokens] => (true, tokens)
    _ => (false, tokens)
  }
  let (table_name, tokens) = self.parse_object_name(tokens)
  ({ table_name, if_exists }, tokens)
}

///|
test "Drop table" {
  let tokens = "DROP TABLE students;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|DROP TABLE students;
    ),
  )
}

///|
test "Drop table IF EXISTS" {
  let tokens = "DROP TABLE IF EXISTS students;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|DROP TABLE IF EXISTS students;
    ),
  )
}

///|
fn Parser::parse_drop_index_statement(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[DropIndexStmt] raise ParserError {
  let tokens = self.expect_token(tokens, Keyword(Drop))
  let tokens = self.expect_token(tokens, Keyword(Index))

  // Parse optional CONCURRENTLY (PostgreSQL)
  let (concurrently, tokens) = match tokens {
    [Keyword(Concurrently), .. tokens] => (true, tokens)
    _ => (false, tokens)
  }

  // Parse optional IF EXISTS
  let (if_exists, tokens) = match tokens {
    [Keyword(If), Keyword(Exists), .. tokens] => (true, tokens)
    _ => (false, tokens)
  }

  // Parse index name
  let (name, tokens) = match tokens {
    [Token::Identifier(name), .. tokens] => (name, tokens)
    [Token::StringLiteral(name), .. tokens] => (name, tokens)
    [token, ..] =>
      raise UnexpectedTokenError(
        token,
        Token::Identifier("index_name".to_string()),
      )
    [] =>
      raise ParserError::InternalBug(
        "parse_drop_index_statement: unexpected end of tokens",
      )
  }

  // Parse optional ON table_name (some dialects)
  let (table_name, tokens) = match tokens {
    [Keyword(On), .. tokens] => {
      let (table_name, tokens) = self.parse_object_name(tokens)
      (Some(table_name), tokens)
    }
    _ => (None, tokens)
  }
  ({ name, if_exists, concurrently, table_name }, tokens)
}

///|
test "DROP INDEX - Simple" {
  let tokens = "DROP INDEX idx_name;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|DROP INDEX idx_name;
    ),
  )
}

///|
test "DROP INDEX IF EXISTS" {
  let tokens = "DROP INDEX IF EXISTS idx_name;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|DROP INDEX IF EXISTS idx_name;
    ),
  )
}

///|
test "DROP INDEX CONCURRENTLY" {
  let tokens = "DROP INDEX CONCURRENTLY idx_name;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|DROP INDEX CONCURRENTLY idx_name;
    ),
  )
}

///|
test "DROP INDEX CONCURRENTLY IF EXISTS" {
  let tokens = "DROP INDEX CONCURRENTLY IF EXISTS idx_name;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|DROP INDEX CONCURRENTLY IF EXISTS idx_name;
    ),
  )
}

///|
test "DROP INDEX with table name" {
  let tokens = "DROP INDEX idx_name ON users;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|DROP INDEX idx_name ON users;
    ),
  )
}

///|
fn Parser::parse_alter_table_statement(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[AlterTableStmt] raise ParserError {
  let tokens = self.expect_token(tokens, Keyword(Alter))
  let tokens = self.expect_token(tokens, Keyword(Table))

  // Parse optional IF EXISTS  
  let (if_exists, tokens) = match tokens {
    [Keyword(If), Keyword(Exists), .. tokens] => (true, tokens)
    _ => (false, tokens)
  }
  let (table_name, tokens) = self.parse_object_name(tokens)

  // Parse table operation
  let (operation, tokens) = match tokens {
    [Keyword(Drop), Keyword(Column), .. tokens] => {
      // Parse optional IF EXISTS for column
      let (column_if_exists, tokens) = match tokens {
        [Keyword(If), Keyword(Exists), .. tokens] => (true, tokens)
        _ => (false, tokens)
      }
      match tokens {
        [Identifier(column_name), .. tokens] =>
          (
            AlterTableOperation::DropColumn(column_name, column_if_exists),
            tokens,
          )
        [token, .. _tokens] =>
          raise UnexpectedTokenMessageError(token, "expected column name")
        [] =>
          raise InternalBug(
            "parse_alter_table_statement: unexpected end of tokens",
          )
      }
    }
    [token, .. _tokens] =>
      raise UnexpectedTokenMessageError(token, "expected table operation")
    [] =>
      raise InternalBug("parse_alter_table_statement: unexpected end of tokens")
  }
  ({ table_name, if_exists, operation }, tokens)
}

///|
/// ALTER INDEX statement
fn Parser::parse_alter_index_statement(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[AlterIndexStmt] raise ParserError {
  let tokens = self.expect_token(tokens, Keyword(Alter))
  let tokens = self.expect_token(tokens, Keyword(Index))

  // Parse optional IF EXISTS
  let (if_exists, tokens) = match tokens {
    [Keyword(If), Keyword(Exists), .. tokens] => (true, tokens)
    _ => (false, tokens)
  }

  // Parse index name
  let (name, tokens) = match tokens {
    [Identifier(name), .. tokens] => (name, tokens)
    [StringLiteral(name), .. tokens] => (name, tokens)
    [token, ..] =>
      raise UnexpectedTokenError(
        token,
        Token::Identifier("index_name".to_string()),
      )
    [] =>
      raise ParserError::InternalBug(
        "parse_alter_index_statement: unexpected end of tokens",
      )
  }

  // Parse operation
  let (operation, tokens) = match tokens {
    [Keyword(Rename), Keyword(To), .. tokens] =>
      match tokens {
        [Identifier(new_name), .. tokens] =>
          (AlterIndexOperation::RenameTo(new_name), tokens)
        [StringLiteral(new_name), .. tokens] =>
          (AlterIndexOperation::RenameTo(new_name), tokens)
        [token, ..] =>
          raise UnexpectedTokenError(
            token,
            Token::Identifier("new_index_name".to_string()),
          )
        [] =>
          raise ParserError::InternalBug(
            "parse_alter_index_statement: expected index name after RENAME TO",
          )
      }
    [Keyword(Set), Keyword(Tablespace), .. tokens] =>
      match tokens {
        [Identifier(tablespace), .. tokens] =>
          (AlterIndexOperation::SetTablespace(tablespace), tokens)
        [StringLiteral(tablespace), .. tokens] =>
          (AlterIndexOperation::SetTablespace(tablespace), tokens)
        [token, ..] =>
          raise UnexpectedTokenError(
            token,
            Token::Identifier("tablespace_name".to_string()),
          )
        [] =>
          raise ParserError::InternalBug(
            "parse_alter_index_statement: expected tablespace name",
          )
      }
    [Keyword(Reset), LParen, .. tokens] => {
      let params = []
      let tokens = loop tokens {
        [Identifier(param), Comma, .. tokens] => {
          params.push(param)
          continue tokens
        }
        [Identifier(param), RParen, .. tokens] => {
          params.push(param)
          break tokens
        }
        [token, ..] =>
          raise UnexpectedTokenError(
            token,
            Token::Identifier("parameter_name".to_string()),
          )
        [] =>
          raise ParserError::InternalBug(
            "parse_alter_index_statement: unexpected end in RESET parameters",
          )
      }
      (AlterIndexOperation::Reset(params), tokens)
    }
    [Keyword(Set), LParen, .. tokens] => {
      let params = []
      let tokens = loop tokens {
        [Identifier(param_name), Eq, .. tokens] => {
          let (value, tokens) = match tokens {
            [Identifier(val), .. tokens] => (val, tokens)
            [StringLiteral(val), .. tokens] => (val, tokens)
            [Number(val), .. tokens] => (val, tokens)
            [token, ..] =>
              raise UnexpectedTokenError(
                token,
                Token::Identifier("parameter_value".to_string()),
              )
            [] =>
              raise ParserError::InternalBug(
                "parse_alter_index_statement: expected parameter value",
              )
          }
          params.push({ name: param_name, value })
          match tokens {
            [Comma, .. tokens] => continue tokens
            [RParen, .. tokens] => break tokens
            [token, ..] => raise UnexpectedTokenError(token, RParen)
            [] =>
              raise ParserError::InternalBug(
                "parse_alter_index_statement: unexpected end in SET parameters",
              )
          }
        }
        [token, ..] =>
          raise UnexpectedTokenError(
            token,
            Token::Identifier("parameter_name".to_string()),
          )
        [] =>
          raise ParserError::InternalBug(
            "parse_alter_index_statement: unexpected end in SET parameters",
          )
      }
      (AlterIndexOperation::Set(params), tokens)
    }
    [token, ..] =>
      raise UnexpectedTokenMessageError(
        token, "expected ALTER INDEX operation (RENAME TO, SET TABLESPACE, RESET, or SET)",
      )
    [] =>
      raise ParserError::InternalBug(
        "parse_alter_index_statement: expected operation after index name",
      )
  }
  ({ name, if_exists, operation }, tokens)
}

///|
test "Alter table drop column" {
  let tokens = "ALTER TABLE mytable DROP COLUMN mycolumn;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|ALTER TABLE mytable DROP COLUMN mycolumn;
    ),
  )
}

///|
test "Alter table drop column IF EXISTS" {
  let tokens = "ALTER TABLE mytable DROP COLUMN IF EXISTS mycolumn;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|ALTER TABLE mytable DROP COLUMN IF EXISTS mycolumn;
    ),
  )
}

///|
test "Alter table IF EXISTS drop column IF EXISTS" {
  let tokens = "ALTER TABLE IF EXISTS mytable DROP COLUMN IF EXISTS mycolumn;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|ALTER TABLE IF EXISTS mytable DROP COLUMN IF EXISTS mycolumn;
    ),
  )
}

///| ALTER INDEX Tests

///|
test "ALTER INDEX - RENAME TO" {
  let tokens = "ALTER INDEX idx_old RENAME TO idx_new;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|ALTER INDEX idx_old RENAME TO idx_new;
    ),
  )
}

///|
test "ALTER INDEX IF EXISTS RENAME TO" {
  let tokens = "ALTER INDEX IF EXISTS idx_old RENAME TO idx_new;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|ALTER INDEX IF EXISTS idx_old RENAME TO idx_new;
    ),
  )
}

///|
test "ALTER INDEX - SET TABLESPACE" {
  let tokens = "ALTER INDEX idx_name SET TABLESPACE fast_ssd;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|ALTER INDEX idx_name SET TABLESPACE fast_ssd;
    ),
  )
}

///|
test "ALTER INDEX - RESET parameters" {
  let tokens = "ALTER INDEX idx_name RESET (fillfactor, fastupdate);"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|ALTER INDEX idx_name RESET (fillfactor, fastupdate);
    ),
  )
}

///|
test "ALTER INDEX - SET parameters" {
  let tokens = "ALTER INDEX idx_name SET (fillfactor = 70, fastupdate = off);"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|ALTER INDEX idx_name SET (fillfactor = 70, fastupdate = off);
    ),
  )
}

///|
test "ALTER INDEX - Simple RENAME test" {
  let tokens = "ALTER INDEX idx_old RENAME TO idx_new;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|ALTER INDEX idx_old RENAME TO idx_new;
    ),
  )
}

///|
test "ALTER INDEX - Complex RENAME with quoted names" {
  let tokens = "ALTER INDEX \"old-index-name\" RENAME TO \"new-index-name\";"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(stmt, content="ALTER INDEX old-index-name RENAME TO new-index-name;")
}

///|
fn Parser::parse_create_database_statement(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[CreateDatabaseStmt] raise ParserError {
  let tokens = self.expect_token(tokens, Keyword(Create))
  let tokens = self.expect_token(tokens, Keyword(Database))

  // Parse optional IF NOT EXISTS
  let (if_not_exists, tokens) = match tokens {
    [Keyword(If), Keyword(Not), Keyword(Exists), .. tokens] => (true, tokens)
    _ => (false, tokens)
  }

  // Parse database name
  let (name, tokens) = match tokens {
    [Token::Identifier(name), .. tokens] => (name, tokens)
    [Token::StringLiteral(name), .. tokens] => (name, tokens)
    [token, ..] =>
      raise UnexpectedTokenError(
        token,
        Token::Identifier("database_name".to_string()),
      )
    [] =>
      raise ParserError::InternalBug(
        "parse_create_database_statement: unexpected end of tokens",
      )
  }

  // Parse optional CHARACTER SET
  let (character_set, tokens) = match tokens {
    [Keyword(Character), Keyword(Set), Token::Identifier(charset), .. tokens] =>
      (Some(charset), tokens)
    [Keyword(Character), Keyword(Set), Token::StringLiteral(charset), .. tokens] =>
      (Some(charset), tokens)
    _ => (None, tokens)
  }

  // Parse optional COLLATE
  let (collate, tokens) = match tokens {
    [Keyword(Collate), Token::Identifier(collation), .. tokens] =>
      (Some(collation), tokens)
    [Keyword(Collate), Token::StringLiteral(collation), .. tokens] =>
      (Some(collation), tokens)
    _ => (None, tokens)
  }
  ({ name, if_not_exists, character_set, collate }, tokens)
}

///|
fn Parser::parse_create_schema_statement(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[CreateSchemaStmt] raise ParserError {
  let tokens = self.expect_token(tokens, Keyword(Create))
  let tokens = self.expect_token(tokens, Keyword(Schema))

  // Parse optional IF NOT EXISTS
  let (if_not_exists, tokens) = match tokens {
    [Keyword(If), Keyword(Not), Keyword(Exists), .. tokens] => (true, tokens)
    _ => (false, tokens)
  }

  // Parse schema name
  let (name, tokens) = match tokens {
    [Token::Identifier(name), .. tokens] => (name, tokens)
    [Token::StringLiteral(name), .. tokens] => (name, tokens)
    [token, ..] =>
      raise UnexpectedTokenError(
        token,
        Token::Identifier("schema_name".to_string()),
      )
    [] =>
      raise ParserError::InternalBug(
        "parse_create_schema_statement: unexpected end of tokens",
      )
  }

  // Parse optional AUTHORIZATION
  let (authorization, tokens) = match tokens {
    [Keyword(Authorization), Token::Identifier(user), .. tokens] =>
      (Some(user), tokens)
    [Keyword(Authorization), Token::StringLiteral(user), .. tokens] =>
      (Some(user), tokens)
    _ => (None, tokens)
  }
  ({ name, if_not_exists, authorization }, tokens)
}

///|
test "CREATE DATABASE - Simple" {
  let tokens = "CREATE DATABASE mydb;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE DATABASE mydb;
    ),
  )
}

///|
test "CREATE DATABASE IF NOT EXISTS" {
  let tokens = "CREATE DATABASE IF NOT EXISTS mydb;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE DATABASE IF NOT EXISTS mydb;
    ),
  )
}

///|
test "CREATE DATABASE with CHARACTER SET" {
  let tokens = "CREATE DATABASE mydb CHARACTER SET utf8;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE DATABASE mydb CHARACTER SET utf8;
    ),
  )
}

///|
test "CREATE DATABASE with CHARACTER SET and COLLATE" {
  let tokens = "CREATE DATABASE mydb CHARACTER SET utf8 COLLATE utf8_general_ci;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE DATABASE mydb CHARACTER SET utf8 COLLATE utf8_general_ci;
    ),
  )
}

///|
test "CREATE SCHEMA - Simple" {
  let tokens = "CREATE SCHEMA myschema;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE SCHEMA myschema;
    ),
  )
}

///|
test "CREATE SCHEMA IF NOT EXISTS" {
  let tokens = "CREATE SCHEMA IF NOT EXISTS myschema;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE SCHEMA IF NOT EXISTS myschema;
    ),
  )
}

///|
test "CREATE SCHEMA with AUTHORIZATION" {
  let tokens = "CREATE SCHEMA myschema AUTHORIZATION myuser;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE SCHEMA myschema AUTHORIZATION myuser;
    ),
  )
}

///|
fn Parser::parse_create_function_statement(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[CreateFunctionStmt] raise ParserError {
  let tokens = self.expect_token(tokens, Keyword(Create))
  let tokens = self.expect_token(tokens, Keyword(Function))

  // Parse optional IF NOT EXISTS
  let (if_not_exists, tokens) = match tokens {
    [Keyword(If), Keyword(Not), Keyword(Exists), .. tokens] => (true, tokens)
    _ => (false, tokens)
  }

  // Parse function name
  let (name, tokens) = match tokens {
    [Token::Identifier(name), .. tokens] => (name, tokens)
    [Token::StringLiteral(name), .. tokens] => (name, tokens)
    [token, ..] =>
      raise UnexpectedTokenError(
        token,
        Token::Identifier("function_name".to_string()),
      )
    [] =>
      raise ParserError::InternalBug(
        "parse_create_function_statement: unexpected end of tokens",
      )
  }

  // Parse parameter list
  let tokens = self.expect_token(tokens, LParen)
  let parameters = []
  let tokens = loop tokens {
    [RParen, .. rest_tokens] => break rest_tokens
    rest_tokens => {
      let (param, rest_tokens) = self.parse_function_parameter(rest_tokens)
      parameters.push(param)
      match rest_tokens {
        [Comma, .. rest_tokens] => continue rest_tokens
        [RParen, .. rest_tokens] => break rest_tokens
        [token, ..] => raise UnexpectedTokenError(token, RParen)
        [] =>
          raise ParserError::InternalBug(
            "parse_create_function_statement: unexpected end of tokens",
          )
      }
    }
  }

  // Parse optional RETURNS clause
  let (return_type, tokens) = match tokens {
    [Keyword(Returns), .. tokens] => {
      let (data_type, tokens) = self.parse_data_type(tokens)
      (Some(data_type), tokens)
    }
    _ => (None, tokens)
  }

  // Parse optional LANGUAGE clause
  let (language, tokens) = match tokens {
    [Keyword(Language), Token::Identifier(lang), .. tokens] =>
      (Some(lang), tokens)
    [Keyword(Language), Token::StringLiteral(lang), .. tokens] =>
      (Some(lang), tokens)
    _ => (None, tokens)
  }

  // Parse optional DETERMINISTIC
  let (deterministic, tokens) = match tokens {
    [Keyword(Deterministic), .. tokens] => (true, tokens)
    _ => (false, tokens)
  }

  // Parse optional body AS 'string'
  let (body, tokens) = match tokens {
    [Keyword(As), Token::StringLiteral(body_text), .. tokens] =>
      (Some(body_text), tokens)
    _ => (None, tokens)
  }
  (
    {
      name,
      parameters,
      return_type,
      language,
      body,
      deterministic,
      if_not_exists,
    },
    tokens,
  )
}

///|
fn Parser::parse_create_procedure_statement(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[CreateProcedureStmt] raise ParserError {
  let tokens = self.expect_token(tokens, Keyword(Create))
  let tokens = self.expect_token(tokens, Keyword(Procedure))

  // Parse optional IF NOT EXISTS
  let (if_not_exists, tokens) = match tokens {
    [Keyword(If), Keyword(Not), Keyword(Exists), .. tokens] => (true, tokens)
    _ => (false, tokens)
  }

  // Parse procedure name
  let (name, tokens) = match tokens {
    [Token::Identifier(name), .. tokens] => (name, tokens)
    [Token::StringLiteral(name), .. tokens] => (name, tokens)
    [token, ..] =>
      raise UnexpectedTokenError(
        token,
        Token::Identifier("procedure_name".to_string()),
      )
    [] =>
      raise ParserError::InternalBug(
        "parse_create_procedure_statement: unexpected end of tokens",
      )
  }

  // Parse parameter list
  let tokens = self.expect_token(tokens, LParen)
  let parameters = []
  let tokens = loop tokens {
    [RParen, .. rest_tokens] => break rest_tokens
    rest_tokens => {
      let (param, rest_tokens) = self.parse_function_parameter(rest_tokens)
      parameters.push(param)
      match rest_tokens {
        [Comma, .. rest_tokens] => continue rest_tokens
        [RParen, .. rest_tokens] => break rest_tokens
        [token, ..] => raise UnexpectedTokenError(token, RParen)
        [] =>
          raise ParserError::InternalBug(
            "parse_create_procedure_statement: unexpected end of tokens",
          )
      }
    }
  }

  // Parse optional LANGUAGE clause
  let (language, tokens) = match tokens {
    [Keyword(Language), Token::Identifier(lang), .. tokens] =>
      (Some(lang), tokens)
    [Keyword(Language), Token::StringLiteral(lang), .. tokens] =>
      (Some(lang), tokens)
    _ => (None, tokens)
  }

  // Parse optional body AS 'string'
  let (body, tokens) = match tokens {
    [Keyword(As), Token::StringLiteral(body_text), .. tokens] =>
      (Some(body_text), tokens)
    _ => (None, tokens)
  }
  ({ name, parameters, language, body, if_not_exists }, tokens)
}

///|
fn Parser::parse_function_parameter(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[FunctionParameter] raise ParserError {
  // Parse optional parameter mode (IN, OUT, INOUT)
  let (mode, tokens) = match tokens {
    [Keyword(In), .. tokens] => (Some(ParameterMode::In), tokens)
    [Keyword(Out), .. tokens] => (Some(ParameterMode::Out), tokens)
    [Keyword(InOut), .. tokens] => (Some(ParameterMode::InOut), tokens)
    _ => (None, tokens)
  }

  // Parse parameter name
  let (name, tokens) = match tokens {
    [Token::Identifier(name), .. tokens] => (name, tokens)
    [Token::StringLiteral(name), .. tokens] => (name, tokens)
    [token, ..] =>
      raise UnexpectedTokenError(
        token,
        Token::Identifier("parameter_name".to_string()),
      )
    [] =>
      raise ParserError::InternalBug(
        "parse_function_parameter: unexpected end of tokens",
      )
  }

  // Parse parameter type
  let (param_type, tokens) = self.parse_data_type(tokens)
  ({ name, param_type, mode }, tokens)
}

///|
test "CREATE FUNCTION - Simple" {
  let tokens = "CREATE FUNCTION my_func() RETURNS INTEGER AS 'SELECT 1';"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE FUNCTION my_func() RETURNS INTEGER AS 'SELECT 1';
    ),
  )
}

///|
test "CREATE FUNCTION IF NOT EXISTS" {
  let tokens = "CREATE FUNCTION IF NOT EXISTS my_func() RETURNS INTEGER AS 'SELECT 1';"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE FUNCTION IF NOT EXISTS my_func() RETURNS INTEGER AS 'SELECT 1';
    ),
  )
}

///|
test "CREATE FUNCTION with parameters" {
  let tokens = "CREATE FUNCTION add_nums(IN a INTEGER, IN b INTEGER) RETURNS INTEGER LANGUAGE sql AS 'SELECT a + b';"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE FUNCTION add_nums(IN a INTEGER, IN b INTEGER) RETURNS INTEGER LANGUAGE sql AS 'SELECT a + b';
    ),
  )
}

///|
test "CREATE FUNCTION DETERMINISTIC" {
  let tokens = "CREATE FUNCTION my_func() RETURNS INTEGER DETERMINISTIC AS 'SELECT 1';"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE FUNCTION my_func() RETURNS INTEGER DETERMINISTIC AS 'SELECT 1';
    ),
  )
}

///|
test "CREATE PROCEDURE - Simple" {
  let tokens = "CREATE PROCEDURE my_proc() AS 'BEGIN SELECT 1; END';"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE PROCEDURE my_proc() AS 'BEGIN SELECT 1; END';
    ),
  )
}

///|
test "CREATE PROCEDURE with parameters" {
  let tokens = "CREATE PROCEDURE update_user(IN user_id INTEGER, IN new_name VARCHAR(100)) LANGUAGE plpgsql AS 'BEGIN UPDATE users SET name = new_name WHERE id = user_id; END';"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE PROCEDURE update_user(IN user_id INTEGER, IN new_name VARCHAR(100)) LANGUAGE plpgsql AS 'BEGIN UPDATE users SET name = new_name WHERE id = user_id; END';
    ),
  )
}

///|
test "CREATE FUNCTION with OUT parameter" {
  let tokens = "CREATE FUNCTION get_user_info(IN user_id INTEGER, OUT user_name VARCHAR(100), OUT user_age INTEGER) AS 'SELECT name, age FROM users WHERE id = user_id';"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE FUNCTION get_user_info(IN user_id INTEGER, OUT user_name VARCHAR(100), OUT user_age INTEGER) AS 'SELECT name, age FROM users WHERE id = user_id';
    ),
  )
}

///|
test "CREATE FUNCTION with INOUT parameter" {
  let tokens = "CREATE FUNCTION modify_value(INOUT value INTEGER) RETURNS INTEGER AS 'SELECT value * 2';"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE FUNCTION modify_value(INOUT value INTEGER) RETURNS INTEGER AS 'SELECT value * 2';
    ),
  )
}

///|
fn Parser::parse_create_sequence_statement(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[CreateSequenceStmt] raise ParserError {
  let tokens = self.expect_token(tokens, Keyword(Create))

  // Parse optional TEMPORARY
  let (temporary, tokens) = match tokens {
    [Keyword(Temporary), .. tokens] => (true, tokens)
    [Keyword(Temp), .. tokens] => (true, tokens)
    _ => (false, tokens)
  }
  let tokens = self.expect_token(tokens, Keyword(Sequence))

  // Parse optional IF NOT EXISTS
  let (if_not_exists, tokens) = match tokens {
    [Keyword(If), Keyword(Not), Keyword(Exists), .. tokens] => (true, tokens)
    _ => (false, tokens)
  }

  // Parse sequence name
  let (name, tokens) = match tokens {
    [Token::Identifier(name), .. tokens] => (name, tokens)
    [Token::StringLiteral(name), .. tokens] => (name, tokens)
    [token, ..] =>
      raise UnexpectedTokenError(
        token,
        Token::Identifier("sequence_name".to_string()),
      )
    [] =>
      raise ParserError::InternalBug(
        "parse_create_sequence_statement: unexpected end of tokens",
      )
  }

  // Parse sequence options
  let mut increment = None
  let mut minvalue = None
  let mut maxvalue = None
  let mut start_with = None
  let mut cache = None
  let mut cycle = None
  let mut owned_by = None
  let tokens = loop tokens {
    [Keyword(Increment), Keyword(By), Number(inc_str), .. rest_tokens] => {
      let inc_val = @strconv.parse_int(inc_str) catch {
        _ => raise ParserError::InvalidDataTypeError(inc_str)
      }
      increment = Some(inc_val)
      continue rest_tokens
    }
    [Keyword(Increment), Number(inc_str), .. rest_tokens] => {
      let inc_val = @strconv.parse_int(inc_str) catch {
        _ => raise ParserError::InvalidDataTypeError(inc_str)
      }
      increment = Some(inc_val)
      continue rest_tokens
    }
    [Keyword(Minvalue), Number(min_str), .. rest_tokens] => {
      let min_val = @strconv.parse_int(min_str) catch {
        _ => raise ParserError::InvalidDataTypeError(min_str)
      }
      minvalue = Some(SequenceLimit::Value(min_val))
      continue rest_tokens
    }
    [Keyword(No), Keyword(Minvalue), .. rest_tokens] => {
      minvalue = Some(SequenceLimit::NoLimit)
      continue rest_tokens
    }
    [Keyword(Maxvalue), Number(max_str), .. rest_tokens] => {
      let max_val = @strconv.parse_int(max_str) catch {
        _ => raise ParserError::InvalidDataTypeError(max_str)
      }
      maxvalue = Some(SequenceLimit::Value(max_val))
      continue rest_tokens
    }
    [Keyword(No), Keyword(Maxvalue), .. rest_tokens] => {
      maxvalue = Some(SequenceLimit::NoLimit)
      continue rest_tokens
    }
    [Keyword(Start), Keyword(With), Number(start_str), .. rest_tokens] => {
      let start_val = @strconv.parse_int(start_str) catch {
        _ => raise ParserError::InvalidDataTypeError(start_str)
      }
      start_with = Some(start_val)
      continue rest_tokens
    }
    [Keyword(Start), Number(start_str), .. rest_tokens] => {
      let start_val = @strconv.parse_int(start_str) catch {
        _ => raise ParserError::InvalidDataTypeError(start_str)
      }
      start_with = Some(start_val)
      continue rest_tokens
    }
    [Keyword(Cache), Number(cache_str), .. rest_tokens] => {
      let cache_val = @strconv.parse_int(cache_str) catch {
        _ => raise ParserError::InvalidDataTypeError(cache_str)
      }
      cache = Some(cache_val)
      continue rest_tokens
    }
    [Keyword(Cycle), .. rest_tokens] => {
      cycle = Some(true)
      continue rest_tokens
    }
    [Keyword(No), Keyword(Cycle), .. rest_tokens] => {
      cycle = Some(false)
      continue rest_tokens
    }
    // More specific OWNED BY patterns first
    [Keyword(Owned), Keyword(By), Identifier("NONE"), .. rest_tokens] => {
      owned_by = Some(SequenceOwnedBy::ByNone)
      continue rest_tokens
    }
    [Keyword(Owned), Keyword(By), Identifier("none"), .. rest_tokens] => {
      owned_by = Some(SequenceOwnedBy::ByNone)
      continue rest_tokens
    }
    // General OWNED BY table.column pattern
    [
      Keyword(Owned),
      Keyword(By),
      Identifier(table_name),
      Period,
      Identifier(column_name),
      .. rest_tokens,
    ] => {
      let table_obj = ObjectName::{ parts: [table_name] }
      owned_by = Some(SequenceOwnedBy::Column(table_obj, column_name))
      continue rest_tokens
    }
    rest_tokens => break rest_tokens
  }
  (
    {
      name,
      if_not_exists,
      temporary,
      increment,
      minvalue,
      maxvalue,
      start_with,
      cache,
      cycle,
      owned_by,
    },
    tokens,
  )
}

///|
test "CREATE SEQUENCE - Simple" {
  let tokens = "CREATE SEQUENCE my_seq;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE SEQUENCE my_seq;
    ),
  )
}

///|
test "CREATE SEQUENCE IF NOT EXISTS" {
  let tokens = "CREATE SEQUENCE IF NOT EXISTS my_seq;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE SEQUENCE IF NOT EXISTS my_seq;
    ),
  )
}

///|
test "CREATE TEMPORARY SEQUENCE" {
  let tokens = "CREATE TEMPORARY SEQUENCE temp_seq;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE TEMPORARY SEQUENCE temp_seq;
    ),
  )
}

///|
test "CREATE SEQUENCE with INCREMENT BY" {
  let tokens = "CREATE SEQUENCE my_seq INCREMENT BY 5;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE SEQUENCE my_seq INCREMENT BY 5;
    ),
  )
}

///|
test "CREATE SEQUENCE with MINVALUE and MAXVALUE" {
  let tokens = "CREATE SEQUENCE my_seq MINVALUE 1 MAXVALUE 1000;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE SEQUENCE my_seq MINVALUE 1 MAXVALUE 1000;
    ),
  )
}

///|
test "CREATE SEQUENCE with NO MINVALUE NO MAXVALUE" {
  let tokens = "CREATE SEQUENCE my_seq NO MINVALUE NO MAXVALUE;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE SEQUENCE my_seq NO MINVALUE NO MAXVALUE;
    ),
  )
}

///|
test "CREATE SEQUENCE with START WITH and CACHE" {
  let tokens = "CREATE SEQUENCE my_seq START WITH 10 CACHE 20;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE SEQUENCE my_seq START WITH 10 CACHE 20;
    ),
  )
}

///|
test "CREATE SEQUENCE with CYCLE" {
  let tokens = "CREATE SEQUENCE my_seq CYCLE;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE SEQUENCE my_seq CYCLE;
    ),
  )
}

///|
test "CREATE SEQUENCE with NO CYCLE" {
  let tokens = "CREATE SEQUENCE my_seq NO CYCLE;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE SEQUENCE my_seq NO CYCLE;
    ),
  )
}

///|
test "CREATE SEQUENCE with OWNED BY" {
  let tokens = "CREATE SEQUENCE user_id_seq OWNED BY users.id;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE SEQUENCE user_id_seq OWNED BY users.id;
    ),
  )
}

///|
test "CREATE SEQUENCE with OWNED BY NONE" {
  let tokens = "CREATE SEQUENCE my_seq OWNED BY NONE;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE SEQUENCE my_seq OWNED BY NONE;
    ),
  )
}

///|
test "CREATE SEQUENCE with all options" {
  let tokens = "CREATE TEMPORARY SEQUENCE IF NOT EXISTS user_seq INCREMENT BY 2 MINVALUE 1 MAXVALUE 9999 START WITH 100 CACHE 10 CYCLE OWNED BY users.id;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|CREATE TEMPORARY SEQUENCE IF NOT EXISTS user_seq INCREMENT BY 2 MINVALUE 1 MAXVALUE 9999 START WITH 100 CACHE 10 CYCLE OWNED BY users.id;
    ),
  )
}
