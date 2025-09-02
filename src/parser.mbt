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
    [Keyword(Drop), Keyword(View), .. _rest] =>
      self.parse_drop_view_statement(tokens).map(Statement::DropView(_))
    [Keyword(Drop), Keyword(Table), .. _rest] =>
      self.parse_drop_table_statement(tokens).map(Statement::DropTable(_))
    [Keyword(Insert), .. _rest] =>
      self.parse_insert_statement(tokens).map(Statement::Insert(_))
    [Keyword(Replace), .. _rest] =>
      self.parse_replace_statement(tokens).map(Statement::Insert(_))
    [Keyword(Delete), .. _rest] =>
      self.parse_delete_statement(tokens).map(Statement::Delete(_))
    [Keyword(Update), .. _rest] =>
      self.parse_update_statement(tokens).map(Statement::Update(_))
    [Keyword(Truncate), .. _rest] =>
      self.parse_truncate_statement(tokens).map(Statement::Truncate(_))
    [Keyword(Alter), Keyword(Table), .. _rest] =>
      self.parse_alter_table_statement(tokens).map(Statement::AlterTable(_))
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
      self.parse_release_savepoint_statement(tokens).map(Statement::ReleaseSavepoint(_))
    [Keyword(Release), .. _rest] =>
      self.parse_release_savepoint_statement(tokens).map(Statement::ReleaseSavepoint(_))
    [Keyword(Grant), .. _rest] =>
      self.parse_grant_statement(tokens).map(Statement::Grant(_))
    [Keyword(Revoke), .. _rest] =>
      self.parse_revoke_statement(tokens).map(Statement::Revoke(_))
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
  
  // Parse optional modifiers (EXTENDED, FULL, GLOBAL/SESSION)
  let mut extended = false
  let mut full = false
  let mut global_scope = false
  
  let tokens = match tokens {
    [Keyword(Extended), .. tokens] => { extended = true; tokens }
    _ => tokens
  }
  
  let tokens = match tokens {
    [Keyword(Full), .. tokens] => { full = true; tokens }
    _ => tokens
  }
  
  let tokens = match tokens {
    [Keyword(Global), .. tokens] => { global_scope = true; tokens }
    [Keyword(Session), .. tokens] => tokens  // SESSION is default
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
      return ({ show_type: ShowType::CreateTable, object: Some(obj_name), filter: None, extended, full, global_scope }, tokens)
    }
    [Keyword(Create), Keyword(View), .. tokens] => {
      // For SHOW CREATE VIEW, the view name comes directly after, not after FROM  
      let (obj_name, tokens) = self.parse_object_name(tokens)
      return ({ show_type: ShowType::CreateView, object: Some(obj_name), filter: None, extended, full, global_scope }, tokens)
    }
    [Keyword(Create), Keyword(Functions), .. tokens] => (ShowType::CreateFunction, tokens)
    [Keyword(Create), Keyword(Procedure), .. tokens] => (ShowType::CreateProcedure, tokens)
    [Keyword(Create), Keyword(Event), .. tokens] => (ShowType::CreateEvent, tokens)
    [Keyword(Create), Keyword(Trigger), .. tokens] => (ShowType::CreateTrigger, tokens)
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
    _ => (SetScope::Local, tokens)  // Default scope
  }
  
  // Parse variable assignments
  let (assignments, tokens) = self.parse_set_assignments(tokens)
  
  // Determine final scope based on first variable name (if any user vars, use UserVar scope)
  let final_scope = if assignments.length() > 0 && assignments[0].variable.strip_prefix("@") != None {
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
    [token, .. _] => raise UnexpectedTokenMessageError(token, "expected variable name")
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
        [token, .. _] => raise UnexpectedTokenMessageError(token, "expected variable name")
        [] => raise InternalBug("parse_set_assignments: unexpected end of tokens after comma")
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
            token, "expected column name in REPLACE column list"
          )
        [] => raise InternalBug("parse_replace_statement: unexpected end of tokens")
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
  
  ({ table_name, columns, source, or: Some(SqliteOnConflict::Replace), on: on_insert }, tokens)
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
      raise UnexpectedTokenMessageError(token, "expected column assignment in ON DUPLICATE KEY UPDATE")
    [] => raise InternalBug("parse_duplicate_key_assignments: unexpected end of tokens")
  }
  (assignments, tokens)
}
