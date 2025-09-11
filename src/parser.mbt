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
  tokens : ArrayView[Token],
  dialect? : &Dialect = MySQL::{  },
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
    [Keyword(With), .. _rest] =>
      self.parse_query(tokens).map(Statement::Query(_))
    [Keyword(Show), .. _rest] =>
      self.parse_show_statement(tokens).map(Statement::Show(_))
    [Keyword(Set), .. _rest] =>
      self.parse_set_statement(tokens).map(Statement::Set(_))
    [Keyword(Create), Keyword(Table), .. _rest] =>
      self.parse_create_table_statement(tokens).map(Statement::CreateTable(_))
    [Keyword(Create), Keyword(View), .. _rest] =>
      self.parse_create_view_statement(tokens).map(Statement::CreateView(_))
    [Keyword(Create), Keyword(Index), .. _rest] =>
      self.parse_create_index_statement(tokens).map(Statement::CreateIndex(_))
    [Keyword(Create), Keyword(Unique), Keyword(Index), .. _rest] =>
      self.parse_create_index_statement(tokens).map(Statement::CreateIndex(_))
    [Keyword(Create), Keyword(Database), .. _rest] =>
      self
      .parse_create_database_statement(tokens)
      .map(Statement::CreateDatabase(_))
    [Keyword(Create), Keyword(Schema), .. _rest] =>
      self.parse_create_schema_statement(tokens).map(Statement::CreateSchema(_))
    [Keyword(Create), Keyword(Function), .. _rest] =>
      self
      .parse_create_function_statement(tokens)
      .map(Statement::CreateFunction(_))
    [Keyword(Create), Keyword(Procedure), .. _rest] =>
      self
      .parse_create_procedure_statement(tokens)
      .map(Statement::CreateProcedure(_))
    [Keyword(Create), Keyword(Sequence), .. _rest] =>
      self
      .parse_create_sequence_statement(tokens)
      .map(Statement::CreateSequence(_))
    [Keyword(Create), Keyword(Temporary), Keyword(Sequence), .. _rest] =>
      self
      .parse_create_sequence_statement(tokens)
      .map(Statement::CreateSequence(_))
    [Keyword(Create), Keyword(Temp), Keyword(Sequence), .. _rest] =>
      self
      .parse_create_sequence_statement(tokens)
      .map(Statement::CreateSequence(_))
    [Keyword(Drop), Keyword(View), .. _rest] =>
      self.parse_drop_view_statement(tokens).map(Statement::DropView(_))
    [Keyword(Drop), Keyword(Table), .. _rest] =>
      self.parse_drop_table_statement(tokens).map(Statement::DropTable(_))
    [Keyword(Drop), Keyword(Index), .. _rest] =>
      self.parse_drop_index_statement(tokens).map(Statement::DropIndex(_))
    [Keyword(Insert), .. _rest] =>
      self.parse_insert_statement(tokens).map(Statement::Insert(_))
    [Keyword(Replace), .. _rest] =>
      self.parse_replace_statement(tokens).map(Statement::Insert(_))
    [Keyword(Delete), .. _rest] =>
      self.parse_delete_statement(tokens).map(Statement::Delete(_))
    [Keyword(Update), .. _rest] =>
      self.parse_update_statement(tokens).map(Statement::Update(_))
    [Keyword(Merge), .. _rest] =>
      self.parse_merge_statement(tokens).map(Statement::Merge(_))
    [Keyword(Truncate), .. _rest] =>
      self.parse_truncate_statement(tokens).map(Statement::Truncate(_))
    [Keyword(Alter), Keyword(Table), .. _rest] =>
      self.parse_alter_table_statement(tokens).map(Statement::AlterTable(_))
    [Keyword(Alter), Keyword(Index), .. _rest] =>
      self.parse_alter_index_statement(tokens).map(Statement::AlterIndex(_))
    [Keyword(Begin), .. _rest] =>
      self.parse_begin_statement(tokens).map(Statement::Begin(_))
    [Keyword(Start), Keyword(Transaction), .. _rest] =>
      self.parse_start_transaction_statement(tokens).map(Statement::Begin(_))
    [Keyword(Commit), .. _rest] =>
      self.parse_commit_statement(tokens).map(Statement::Commit(_))
    [Keyword(Rollback), .. _rest] =>
      self.parse_rollback_statement(tokens).map(Statement::Rollback(_))
    [Keyword(Savepoint), .. _rest] =>
      self.parse_savepoint_statement(tokens).map(Statement::Savepoint(_))
    [Keyword(Release), Keyword(Savepoint), .. _rest] =>
      self
      .parse_release_savepoint_statement(tokens)
      .map(Statement::ReleaseSavepoint(_))
    [Keyword(Release), .. _rest] =>
      self
      .parse_release_savepoint_statement(tokens)
      .map(Statement::ReleaseSavepoint(_))
    [Keyword(Grant), .. _rest] =>
      self.parse_grant_statement(tokens).map(Statement::Grant(_))
    [Keyword(Revoke), .. _rest] =>
      self.parse_revoke_statement(tokens).map(Statement::Revoke(_))
    [Keyword(Use), .. _rest] =>
      self.parse_use_statement(tokens).map(Statement::Use(_))
    [Keyword(Copy), .. _rest] =>
      self.parse_copy_statement(tokens).map(Statement::Copy(_))
    [LParen, .. rest] => {
      let (stmt, tokens) = self.parse_statement(rest)
      let tokens = self.expect_token(tokens, RParen)
      (stmt, tokens)
    }
    _ => raise UnexpectedTokenMessageError(tokens[0], "start of a statement")
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

  // Parse optional modifiers (EXTENDED, FULL, GLOBAL/SESSION)
  let mut extended = false
  let mut full = false
  let mut global_scope = false
  let tokens = match tokens {
    [Keyword(Extended), .. tokens] => {
      extended = true
      tokens
    }
    _ => tokens
  }
  let tokens = match tokens {
    [Keyword(Full), .. tokens] => {
      full = true
      tokens
    }
    _ => tokens
  }
  let tokens = match tokens {
    [Keyword(Global), .. tokens] => {
      global_scope = true
      tokens
    }
    [Keyword(Session), .. tokens] => tokens // SESSION is default
    _ => tokens
  }
  let (show_type, tokens) = match tokens {
    [Keyword(Tables), .. tokens] => (ShowType::Tables, tokens)
    [Keyword(Columns), .. tokens] => (ShowType::Columns, tokens)
    [Keyword(Status), .. tokens] => (ShowType::Status, tokens)
    [Keyword(Databases), .. tokens] => (ShowType::Databases, tokens)
    [Keyword(Schemas), .. tokens] => (ShowType::Schemas, tokens)
    [Keyword(Variables), .. tokens] => (ShowType::Variables, tokens)
    [Keyword(Processlist), .. tokens] => (ShowType::Processlist, tokens)
    [Keyword(Grants), .. tokens] => (ShowType::Grants, tokens)
    [Keyword(Functions), .. tokens] => (ShowType::Functions, tokens)
    [Keyword(Create), Keyword(Table), .. tokens] => {
      // For SHOW CREATE TABLE, the table name comes directly after, not after FROM
      let (obj_name, tokens) = self.parse_object_name(tokens)
      return (
        {
          show_type: ShowType::CreateTable,
          object: Some(obj_name),
          filter: None,
          extended,
          full,
          global_scope,
        },
        tokens,
      )
    }
    [Keyword(Create), Keyword(View), .. tokens] => {
      // For SHOW CREATE VIEW, the view name comes directly after, not after FROM  
      let (obj_name, tokens) = self.parse_object_name(tokens)
      return (
        {
          show_type: ShowType::CreateView,
          object: Some(obj_name),
          filter: None,
          extended,
          full,
          global_scope,
        },
        tokens,
      )
    }
    [Keyword(Create), Keyword(Functions), .. tokens] =>
      (ShowType::CreateFunction, tokens)
    [Keyword(Create), Keyword(Procedure), .. tokens] =>
      (ShowType::CreateProcedure, tokens)
    [Keyword(Create), Keyword(Event), .. tokens] =>
      (ShowType::CreateEvent, tokens)
    [Keyword(Create), Keyword(Trigger), .. tokens] =>
      (ShowType::CreateTrigger, tokens)
    [token, .. _tokens] =>
      raise UnexpectedTokenMessageError(token, "expected SHOW statement type")
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
  ({ show_type, object, filter, extended, full, global_scope }, tokens)
}

///|
fn Parser::parse_set_statement(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[SetStmt] raise ParserError {
  let tokens = self.expect_token(tokens, Keyword(Set))

  // Parse scope (GLOBAL, SESSION, or default)
  let (scope, tokens) = match tokens {
    [Keyword(Global), .. tokens] => (SetScope::Global, tokens)
    [Keyword(Session), .. tokens] => (SetScope::Session, tokens)
    _ => (SetScope::Local, tokens) // Default scope
  }

  // Parse variable assignments
  let (assignments, tokens) = self.parse_set_assignments(tokens)

  // Determine final scope based on first variable name (if any user vars, use UserVar scope)
  let final_scope = if assignments.length() > 0 &&
    assignments[0].variable.strip_prefix("@") != None {
    SetScope::UserVar
  } else {
    scope
  }
  ({ scope: final_scope, assignments }, tokens)
}

///|
fn Parser::parse_set_assignments(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[Array[SetAssignment]] raise ParserError {
  let assignments : Array[SetAssignment] = []

  // Parse first assignment
  let (variable, tokens) = match tokens {
    [Identifier(name), .. rest] => (name, rest)
    [token, ..] =>
      raise UnexpectedTokenMessageError(token, "expected variable name")
    [] => raise InternalBug("parse_set_assignments: unexpected end of tokens")
  }
  let tokens = self.expect_token(tokens, Eq)
  let (value, tokens) = self.parse_expr(tokens)
  assignments.push({ variable, value })

  // Parse additional assignments
  loop tokens {
    [Comma, .. rest] => {
      let (variable, remaining_tokens) = match rest {
        [Identifier(name), .. remaining] => (name, remaining)
        [token, ..] =>
          raise UnexpectedTokenMessageError(token, "expected variable name")
        [] =>
          raise InternalBug(
            "parse_set_assignments: unexpected end of tokens after comma",
          )
      }
      let remaining_tokens = self.expect_token(remaining_tokens, Eq)
      let (value, remaining_tokens) = self.parse_expr(remaining_tokens)
      assignments.push({ variable, value })
      continue remaining_tokens
    }
    tokens => break (assignments, tokens)
  }
}

///|
fn Parser::parse_replace_statement(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[InsertStmt] raise ParserError {
  let tokens = self.expect_token(tokens, Keyword(Replace))
  let tokens = self.expect_token(tokens, Keyword(Into))

  // Parse table name
  let (table_name, tokens) = self.parse_object_name(tokens)

  // Parse optional column list: (col1, col2, ...)
  let (columns, tokens) = match tokens {
    [LParen, .. tokens] => {
      let columns = []
      let tokens = loop tokens {
        [Identifier(col), Comma, .. tokens] => {
          columns.push(col)
          continue tokens
        }
        [Identifier(col), RParen, .. tokens] => {
          columns.push(col)
          break tokens
        }
        [token, .. _tokens] =>
          raise UnexpectedTokenMessageError(
            token, "expected column name in REPLACE column list",
          )
        [] =>
          raise InternalBug("parse_replace_statement: unexpected end of tokens")
      }
      (columns, tokens)
    }
    _ => ([], tokens)
  }

  // Parse VALUES (...) or SELECT query
  let (source, tokens) = match tokens {
    [Keyword(Values), .. tokens] => {
      let values = []
      let tokens = loop tokens {
        [LParen, .. tokens] => {
          let (exprs, tokens) = self.parse_comma_separated_exprs(tokens)
          let tokens = self.expect_token(tokens, RParen)
          values.push(exprs)
          match tokens {
            [Comma, .. tokens] => continue tokens
            tokens => break tokens
          }
        }
        tokens => break tokens
      }
      (InsertSource::Values(values), tokens)
    }
    [Keyword(Select), .. _rest] => {
      let (query, tokens) = self.parse_query(tokens)
      (InsertSource::Query(query), tokens)
    }
    _ => raise UnexpectedTokenError(tokens[0], Keyword(Values))
  }

  // Parse optional ON DUPLICATE KEY UPDATE clause (even for REPLACE)
  let (on_insert, tokens) = match tokens {
    [Keyword(On), Keyword(Duplicate), Keyword(Key), Keyword(Update), .. tokens] => {
      let (assignments, tokens) = self.parse_duplicate_key_assignments(tokens)
      (Some(OnInsert::DuplicateKeyUpdate(assignments)), tokens)
    }
    _ => (None, tokens)
  }
  (
    {
      table_name,
      columns,
      source,
      or: Some(SqliteOnConflict::Replace),
      on: on_insert,
    },
    tokens,
  )
}

///|
fn Parser::parse_copy_statement(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[CopyStmt] raise ParserError {
  let tokens = self.expect_token(tokens, Keyword(Copy))

  // Parse source (table or query)
  let (source, tokens) = match tokens {
    [LParen, .. tokens] => {
      // COPY (SELECT ...) TO/FROM ...
      let (query, tokens) = self.parse_query(tokens)
      let tokens = self.expect_token(tokens, RParen)
      (CopySource::Query(query), tokens)
    }
    _ => {
      // COPY table_name [(column_list)] TO/FROM ...
      let (table_name, tokens) = self.parse_object_name(tokens)

      // Parse optional column list
      let (columns, tokens) = match tokens {
        [LParen, .. tokens] => {
          let columns = []
          let tokens = loop tokens {
            [Identifier(col), Comma, .. tokens] => {
              columns.push(col)
              continue tokens
            }
            [Identifier(col), RParen, .. tokens] => {
              columns.push(col)
              break tokens
            }
            [token, .. _tokens] =>
              raise UnexpectedTokenMessageError(
                token, "expected column name in COPY column list",
              )
            [] =>
              raise InternalBug(
                "parse_copy_statement: unexpected end of tokens in column list",
              )
          }
          (Some(columns), tokens)
        }
        _ => (None, tokens)
      }
      (CopySource::Table(table_name, columns), tokens)
    }
  }

  // Parse direction (TO or FROM)
  let (direction, tokens) = match tokens {
    [Keyword(To), .. tokens] => (CopyDirection::To, tokens)
    [Keyword(From), .. tokens] => (CopyDirection::From, tokens)
    [token, .. _tokens] =>
      raise UnexpectedTokenMessageError(
        token, "expected TO or FROM in COPY statement",
      )
    [] =>
      raise InternalBug(
        "parse_copy_statement: unexpected end of tokens after source",
      )
  }

  // Parse target (file, stdin, stdout, or program)
  let (target, tokens) = match tokens {
    [Keyword(Stdin), .. tokens] => (CopyTarget::Stdin, tokens)
    [Keyword(Stdout), .. tokens] => (CopyTarget::Stdout, tokens)
    [Keyword(Program), StringLiteral(command), .. tokens] =>
      (CopyTarget::Program(command), tokens)
    [StringLiteral(filename), .. tokens] => (CopyTarget::File(filename), tokens)
    [token, .. _tokens] =>
      raise UnexpectedTokenMessageError(
        token, "expected filename, STDIN, STDOUT, or PROGRAM in COPY statement",
      )
    [] =>
      raise InternalBug(
        "parse_copy_statement: unexpected end of tokens after direction",
      )
  }

  // Parse optional format options
  let (format_options, tokens) = match tokens {
    [LParen, .. tokens] => self.parse_copy_options(tokens)
    _ => ([], tokens)
  }
  ({ source, direction, target, format_options }, tokens)
}

///|
fn Parser::parse_copy_options(
  _self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[Array[CopyOption]] raise ParserError {
  let options = []
  let tokens = loop tokens {
    [RParen, .. tokens] => break tokens
    [Keyword(Format), Identifier("csv"), .. tokens] => {
      options.push(CopyOption::Format(CopyFormat::Csv))
      match tokens {
        [Comma, .. tokens] => continue tokens
        _ => continue tokens
      }
    }
    [Keyword(Format), Identifier("text"), .. tokens] => {
      options.push(CopyOption::Format(CopyFormat::Text))
      match tokens {
        [Comma, .. tokens] => continue tokens
        _ => continue tokens
      }
    }
    [Keyword(Format), Identifier("binary"), .. tokens] => {
      options.push(CopyOption::Format(CopyFormat::Binary))
      match tokens {
        [Comma, .. tokens] => continue tokens
        _ => continue tokens
      }
    }
    [Identifier("delimiter"), StringLiteral(delim), .. tokens] => {
      options.push(CopyOption::Delimiter(delim))
      match tokens {
        [Comma, .. tokens] => continue tokens
        _ => continue tokens
      }
    }
    [Identifier("quote"), StringLiteral(quote_char), .. tokens] => {
      options.push(CopyOption::Quote(quote_char))
      match tokens {
        [Comma, .. tokens] => continue tokens
        _ => continue tokens
      }
    }
    [Identifier("escape"), StringLiteral(escape_char), .. tokens] => {
      options.push(CopyOption::Escape(escape_char))
      match tokens {
        [Comma, .. tokens] => continue tokens
        _ => continue tokens
      }
    }
    [Keyword(Null), StringLiteral(null_str), .. tokens] => {
      options.push(CopyOption::Null(null_str))
      match tokens {
        [Comma, .. tokens] => continue tokens
        _ => continue tokens
      }
    }
    [Keyword(Header), Boolean(value), .. tokens] => {
      options.push(CopyOption::Header(Some(value)))
      match tokens {
        [Comma, .. tokens] => continue tokens
        _ => continue tokens
      }
    }
    [Keyword(Header), .. tokens] => {
      options.push(CopyOption::Header(None))
      match tokens {
        [Comma, .. tokens] => continue tokens
        _ => continue tokens
      }
    }
    [Keyword(ForceQuote), Mul, .. tokens] => {
      options.push(CopyOption::ForceQuote(CopyForceQuote::All))
      match tokens {
        [Comma, .. tokens] => continue tokens
        _ => continue tokens
      }
    }
    [Keyword(ForceQuote), LParen, .. tokens] => {
      let columns = []
      let tokens = loop tokens {
        [Identifier(col), Comma, .. tokens] => {
          columns.push(col)
          continue tokens
        }
        [Identifier(col), RParen, .. tokens] => {
          columns.push(col)
          break tokens
        }
        [token, .. _tokens] =>
          raise UnexpectedTokenMessageError(
            token, "expected column name in FORCE_QUOTE",
          )
        [] =>
          raise InternalBug("parse_copy_options: unexpected end in FORCE_QUOTE")
      }
      options.push(CopyOption::ForceQuote(CopyForceQuote::Columns(columns)))
      match tokens {
        [Comma, .. tokens] => continue tokens
        _ => continue tokens
      }
    }
    [Keyword(ForceNotNull), LParen, .. tokens] => {
      let columns = []
      let tokens = loop tokens {
        [Identifier(col), Comma, .. tokens] => {
          columns.push(col)
          continue tokens
        }
        [Identifier(col), RParen, .. tokens] => {
          columns.push(col)
          break tokens
        }
        [token, .. _tokens] =>
          raise UnexpectedTokenMessageError(
            token, "expected column name in FORCE_NOT_NULL",
          )
        [] =>
          raise InternalBug(
            "parse_copy_options: unexpected end in FORCE_NOT_NULL",
          )
      }
      options.push(CopyOption::ForceNotNull(columns))
      match tokens {
        [Comma, .. tokens] => continue tokens
        _ => continue tokens
      }
    }
    [Keyword(ForceNull), LParen, .. tokens] => {
      let columns = []
      let tokens = loop tokens {
        [Identifier(col), Comma, .. tokens] => {
          columns.push(col)
          continue tokens
        }
        [Identifier(col), RParen, .. tokens] => {
          columns.push(col)
          break tokens
        }
        [token, .. _tokens] =>
          raise UnexpectedTokenMessageError(
            token, "expected column name in FORCE_NULL",
          )
        [] =>
          raise InternalBug("parse_copy_options: unexpected end in FORCE_NULL")
      }
      options.push(CopyOption::ForceNull(columns))
      match tokens {
        [Comma, .. tokens] => continue tokens
        _ => continue tokens
      }
    }
    [Keyword(Encoding), StringLiteral(encoding), .. tokens] => {
      options.push(CopyOption::Encoding(encoding))
      match tokens {
        [Comma, .. tokens] => continue tokens
        _ => continue tokens
      }
    }
    [token, .. _tokens] =>
      raise UnexpectedTokenMessageError(token, "expected COPY option")
    [] => raise InternalBug("parse_copy_options: unexpected end of tokens")
  }
  (options, tokens)
}

///|
fn Parser::parse_use_statement(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[UseStmt] raise ParserError {
  let tokens = self.expect_token(tokens, Keyword(Use))

  // Parse database name
  let (database_name, tokens) = self.parse_object_name(tokens)
  ({ database_name, }, tokens)
}

///|
fn Parser::parse_comma_separated_exprs(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[Array[Expr]] raise ParserError {
  let exprs = []
  let (expr, tokens) = self.parse_expr(tokens)
  exprs.push(expr)
  let tokens = loop tokens {
    [Comma, .. tokens] => {
      let (expr, tokens) = self.parse_expr(tokens)
      exprs.push(expr)
      continue tokens
    }
    tokens => break tokens
  }
  (exprs, tokens)
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

///|
test "Parse USE database statement" {
  let tokens = [Keyword(Use), Token::Identifier("mydb"), Token::Semicolon]
  let stmt = parse(tokens)[0] |> pretty_print
  inspect(stmt, content="USE mydb;")
}

///|
test "Parse USE database statement with qualified name" {
  let tokens = [
    Keyword(Use),
    Token::Identifier("company"),
    Token::Period,
    Token::Identifier("production"),
    Token::Semicolon,
  ]
  let stmt = parse(tokens)[0] |> pretty_print
  inspect(stmt, content="USE company.production;")
}

///|
test "Parse USE database statement with backtick quoted name" {
  let tokens = [
    Keyword(Use),
    Token::Identifier("my database"),
    Token::Semicolon,
  ]
  let stmt = parse(tokens)[0] |> pretty_print
  inspect(stmt, content="USE `my database`;")
}

///|
test "Parse COPY table TO file" {
  let tokens = [
    Keyword(Copy),
    Token::Identifier("users"),
    Keyword(To),
    Token::StringLiteral("/tmp/users.csv"),
    Token::Semicolon,
  ]
  let stmt = parse(tokens)[0] |> pretty_print
  inspect(stmt, content="COPY users TO '/tmp/users.csv';")
}

///|
test "Parse COPY table FROM file with CSV format" {
  let tokens = [
    Keyword(Copy),
    Token::Identifier("products"),
    Keyword(From),
    Token::StringLiteral("/data/products.csv"),
    Token::LParen,
    Keyword(Format),
    Token::Identifier("csv"),
    Token::Comma,
    Keyword(Header),
    Token::RParen,
    Token::Semicolon,
  ]
  let stmt = parse(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content="COPY products FROM '/data/products.csv' (FORMAT CSV, HEADER);",
  )
}

///|
test "Parse COPY table with column list TO STDOUT" {
  let tokens = [
    Keyword(Copy),
    Token::Identifier("orders"),
    Token::LParen,
    Token::Identifier("id"),
    Token::Comma,
    Token::Identifier("amount"),
    Token::RParen,
    Keyword(To),
    Keyword(Stdout),
    Token::Semicolon,
  ]
  let stmt = parse(tokens)[0] |> pretty_print
  inspect(stmt, content="COPY orders (id, amount) TO STDOUT;")
}

///|
test "Parse COPY query TO file with options" {
  let tokens = [
    Keyword(Copy),
    Token::LParen,
    Keyword(Select),
    Token::Mul,
    Keyword(From),
    Token::Identifier("customers"),
    Token::RParen,
    Keyword(To),
    Token::StringLiteral("/tmp/customers.csv"),
    Token::LParen,
    Keyword(Format),
    Token::Identifier("csv"),
    Token::Comma,
    Token::Identifier("delimiter"),
    Token::StringLiteral(","),
    Token::Comma,
    Keyword(Null),
    Token::StringLiteral(""),
    Token::RParen,
    Token::Semicolon,
  ]
  let stmt = parse(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content="COPY (\n  SELECT\n    *\n  FROM\n    customers\n) TO '/tmp/customers.csv' (FORMAT CSV, DELIMITER ',', NULL '');",
  )
}

///|
test "Parse COPY FROM STDIN with comprehensive options" {
  let tokens = [
    Keyword(Copy),
    Token::Identifier("employees"),
    Keyword(From),
    Keyword(Stdin),
    Token::LParen,
    Keyword(Format),
    Token::Identifier("csv"),
    Token::Comma,
    Token::Identifier("quote"),
    Token::StringLiteral("\""),
    Token::Comma,
    Token::Identifier("escape"),
    Token::StringLiteral("\\"),
    Token::Comma,
    Keyword(ForceQuote),
    Token::Mul,
    Token::RParen,
    Token::Semicolon,
  ]
  let stmt = parse(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content="COPY employees FROM STDIN (FORMAT CSV, QUOTE '\"', ESCAPE '\\', FORCE_QUOTE *);",
  )
}

///|
fn Parser::parse_duplicate_key_assignments(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[Array[Assignment]] raise ParserError {
  let assignments = []
  let tokens = loop tokens {
    [Identifier(column), Eq, .. tokens] => {
      let (value, tokens) = self.parse_expr(tokens)
      assignments.push({ column, value })
      match tokens {
        [Comma, .. tokens] => continue tokens
        _ => break tokens
      }
    }
    [token, .. _tokens] =>
      raise UnexpectedTokenMessageError(
        token, "expected column assignment in ON DUPLICATE KEY UPDATE",
      )
    [] =>
      raise InternalBug(
        "parse_duplicate_key_assignments: unexpected end of tokens",
      )
  }
  (assignments, tokens)
}

///|
fn Parser::parse_on_conflict_clause(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[OnConflictClause] raise ParserError {
  // Parse optional conflict target
  let (conflict_target, tokens) = match tokens {
    [LParen, .. tokens] => {
      // Parse column list or expression
      let (first_expr, tokens) = self.parse_expr(tokens)

      // Check if it's a simple column list or expression
      match tokens {
        [Comma, .. tokens] => {
          // It's a column list: (col1, col2, ...)
          let columns = []
          // Extract column name from first expression if it's an identifier
          match first_expr {
            Expr::Identifier(name) => columns.push(name)
            _ =>
              raise UnexpectedTokenMessageError(
                tokens[0],
                "expected column name in conflict target",
              )
          }
          let tokens = loop tokens {
            [Identifier(col), Comma, .. tokens] => {
              columns.push(col)
              continue tokens
            }
            [Identifier(col), RParen, .. tokens] => {
              columns.push(col)
              break tokens
            }
            [token, ..] =>
              raise UnexpectedTokenMessageError(token, "expected column name")
            [] =>
              raise InternalBug(
                "parse_on_conflict_clause: unexpected end in column list",
              )
          }

          // Check for optional WHERE condition after parentheses
          let (where_condition, tokens) = match tokens {
            [Keyword(Where), .. tokens] => {
              let (condition, tokens) = self.parse_expr(tokens)
              (Some(condition), tokens)
            }
            _ => (None, tokens)
          }

          // For multiple columns, use Columns variant if no WHERE condition, otherwise OnExpression
          match where_condition {
            None => (Some(ConflictTarget::Columns(columns)), tokens)
            Some(_condition) =>
              (
                Some(
                  ConflictTarget::OnExpression(
                    Expr::CompoundIdentifier(columns),
                    where_condition,
                  ),
                ),
                tokens,
              )
          }
        }
        [RParen, .. tokens] => {
          // Single expression or column

          // Check for optional WHERE condition after parentheses
          let (where_condition, tokens) = match tokens {
            [Keyword(Where), .. tokens] => {
              let (condition, tokens) = self.parse_expr(tokens)
              (Some(condition), tokens)
            }
            _ => (None, tokens)
          }
          match first_expr {
            Expr::Identifier(name) =>
              // Single column case
              match where_condition {
                None => (Some(ConflictTarget::Columns([name])), tokens)
                Some(_) =>
                  (
                    Some(
                      ConflictTarget::OnExpression(first_expr, where_condition),
                    ),
                    tokens,
                  )
              }
            _ =>
              (
                Some(ConflictTarget::OnExpression(first_expr, where_condition)),
                tokens,
              )
          }
        }
        [token, ..] => raise UnexpectedTokenError(token, RParen)
        [] =>
          raise InternalBug(
            "parse_on_conflict_clause: unexpected end after expression",
          )
      }
    }
    [Keyword(On), Keyword(Constraint), Identifier(constraint_name), .. tokens] =>
      (Some(ConflictTarget::OnConstraint(constraint_name)), tokens)
    _ => (None, tokens)
  }

  // Parse conflict action (DO NOTHING or DO UPDATE SET ...)
  let (conflict_action, tokens) = match tokens {
    [Keyword(Do), Keyword(Nothing), .. tokens] =>
      (ConflictAction::DoNothing, tokens)
    [Keyword(Do), Keyword(Update), Keyword(Set), .. tokens] => {
      let (assignments, tokens) = self.parse_duplicate_key_assignments(tokens)

      // Parse optional WHERE clause for DO UPDATE
      let (where_condition, tokens) = match tokens {
        [Keyword(Where), .. tokens] => {
          let (condition, tokens) = self.parse_expr(tokens)
          (Some(condition), tokens)
        }
        _ => (None, tokens)
      }
      (ConflictAction::DoUpdate(assignments, where_condition), tokens)
    }
    [token, ..] =>
      raise UnexpectedTokenMessageError(
        token, "expected DO NOTHING or DO UPDATE SET",
      )
    [] =>
      raise InternalBug("parse_on_conflict_clause: expected conflict action")
  }
  ({ conflict_target, conflict_action }, tokens)
}

///|
fn Parser::parse_load_data_statement(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[LoadDataStmt] raise ParserError {
  let tokens = self.expect_token(tokens, Keyword(Load))
  let tokens = self.expect_token(tokens, Keyword(Data))

  // Parse optional LOCAL keyword
  let (is_local, tokens) = match tokens {
    [Keyword(Local), .. tokens] => (true, tokens)
    _ => (false, tokens)
  }

  // Parse INFILE 'filename'
  let tokens = self.expect_token(tokens, Keyword(Infile))
  let (filename, tokens) = match tokens {
    [StringLiteral(filename), .. tokens] => (filename, tokens)
    [token, ..] =>
      raise UnexpectedTokenMessageError(
        token, "expected filename string after INFILE",
      )
    [] =>
      raise InternalBug(
        "parse_load_data_statement: unexpected end after INFILE",
      )
  }

  // Parse optional REPLACE or IGNORE
  let (duplicate_handling, tokens) = match tokens {
    [Keyword(Replace), .. tokens] =>
      (Some(LoadDataDuplicateHandling::Replace), tokens)
    [Keyword(Ignore), .. tokens] =>
      (Some(LoadDataDuplicateHandling::Ignore), tokens)
    _ => (None, tokens)
  }

  // Parse INTO TABLE table_name
  let tokens = self.expect_token(tokens, Keyword(Into))
  let tokens = self.expect_token(tokens, Keyword(Table))
  let (table_name, tokens) = self.parse_object_name(tokens)

  // Parse optional CHARACTER SET
  let (character_set, tokens) = match tokens {
    [Keyword(Character), Keyword(Set), Identifier(charset), .. tokens] =>
      (Some(charset), tokens)
    _ => (None, tokens)
  }

  // Parse optional FIELDS clause
  let (fields_options, tokens) = match tokens {
    [Keyword(Fields), .. tokens] => {
      let (fields_opts, tokens) = self.parse_load_data_fields_options(tokens)
      (Some(fields_opts), tokens)
    }
    _ => (None, tokens)
  }

  // Parse optional LINES clause
  let (lines_options, tokens) = match tokens {
    [Keyword(Lines), .. tokens] => {
      let (lines_opts, tokens) = self.parse_load_data_lines_options(tokens)
      (Some(lines_opts), tokens)
    }
    _ => (None, tokens)
  }

  // Parse optional IGNORE number LINES
  let (ignore_lines, tokens) = match tokens {
    [Keyword(Ignore), Number(num_str), Keyword(Lines), .. tokens] => {
      // Convert string to integer
      let num = @strconv.parse_int(num_str) catch {
        _ =>
          raise UnexpectedTokenMessageError(
            tokens[0],
            "expected valid number for IGNORE lines",
          )
      }
      (Some(num), tokens)
    }
    _ => (None, tokens)
  }

  // Parse optional column list: (col1, col2, ...)
  let (columns, tokens) = match tokens {
    [LParen, .. tokens] => {
      let columns = []
      let tokens = loop tokens {
        [Identifier(col), Comma, .. tokens] => {
          columns.push(col)
          continue tokens
        }
        [Identifier(col), RParen, .. tokens] => {
          columns.push(col)
          break tokens
        }
        // Allow keywords to be used as column names
        [Keyword(Date), Comma, .. tokens] => {
          columns.push("date")
          continue tokens
        }
        [Keyword(Date), RParen, .. tokens] => {
          columns.push("date")
          break tokens
        }
        [Keyword(Year), Comma, .. tokens] => {
          columns.push("year")
          continue tokens
        }
        [Keyword(Year), RParen, .. tokens] => {
          columns.push("year")
          break tokens
        }
        [Keyword(Month), Comma, .. tokens] => {
          columns.push("month")
          continue tokens
        }
        [Keyword(Month), RParen, .. tokens] => {
          columns.push("month")
          break tokens
        }
        [Keyword(Day), Comma, .. tokens] => {
          columns.push("day")
          continue tokens
        }
        [Keyword(Day), RParen, .. tokens] => {
          columns.push("day")
          break tokens
        }
        [token, ..] =>
          raise UnexpectedTokenMessageError(
            token, "expected column name in LOAD DATA column list",
          )
        [] =>
          raise InternalBug(
            "parse_load_data_statement: unexpected end in column list",
          )
      }
      (Some(columns), tokens)
    }
    _ => (None, tokens)
  }

  // Parse optional SET assignments
  let (set_assignments, tokens) = match tokens {
    [Keyword(Set), .. tokens] => {
      let (assignments, tokens) = self.parse_duplicate_key_assignments(tokens)
      (Some(assignments), tokens)
    }
    _ => (None, tokens)
  }
  (
    {
      is_local,
      filename,
      duplicate_handling,
      table_name,
      character_set,
      fields_options,
      lines_options,
      ignore_lines,
      columns,
      set_assignments,
    },
    tokens,
  )
}

///|
fn Parser::parse_load_data_fields_options(
  _self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[LoadDataFieldsOptions] {
  let mut terminated_by = None
  let mut enclosed_by = None
  let mut optionally_enclosed = false
  let mut escaped_by = None
  let tokens = loop tokens {
    [Keyword(Terminated), Keyword(By), StringLiteral(term), .. tokens] => {
      terminated_by = Some(term)
      continue tokens
    }
    [
      Keyword(Optionally),
      Keyword(Enclosed),
      Keyword(By),
      StringLiteral(enc),
      .. tokens,
    ] => {
      enclosed_by = Some(enc)
      optionally_enclosed = true
      continue tokens
    }
    [Keyword(Enclosed), Keyword(By), StringLiteral(enc), .. tokens] => {
      enclosed_by = Some(enc)
      optionally_enclosed = false
      continue tokens
    }
    [Keyword(Escaped), Keyword(By), StringLiteral(esc), .. tokens] => {
      escaped_by = Some(esc)
      continue tokens
    }
    tokens => break tokens
  }
  ({ terminated_by, enclosed_by, optionally_enclosed, escaped_by }, tokens)
}

///|
fn Parser::parse_load_data_lines_options(
  _self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[LoadDataLinesOptions] {
  let mut starting_by = None
  let mut terminated_by = None
  let tokens = loop tokens {
    [Keyword(Starting), Keyword(By), StringLiteral(start), .. tokens] => {
      starting_by = Some(start)
      continue tokens
    }
    [Keyword(Terminated), Keyword(By), StringLiteral(term), .. tokens] => {
      terminated_by = Some(term)
      continue tokens
    }
    tokens => break tokens
  }
  ({ starting_by, terminated_by }, tokens)
}
