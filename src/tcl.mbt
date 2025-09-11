///|
// TCL (Transaction Control Language) parsing functions

///|
fn Parser::parse_begin_statement(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[BeginStmt] raise ParserError {
  let tokens = self.expect_token(tokens, Keyword(Begin))

  // Parse optional WORK or TRANSACTION keywords
  let mut work = false
  let mut transaction = false
  let tokens = match tokens {
    [Keyword(Transaction), .. tokens] => {
      transaction = true
      tokens
    }
    [Keyword(Work), .. tokens] => {
      work = true
      // WORK can be followed by TRANSACTION
      match tokens {
        [Keyword(Transaction), .. tokens] => {
          transaction = true
          tokens
        }
        _ => tokens
      }
    }
    _ => tokens
  }
  ({ work, transaction }, tokens)
}

///|
fn Parser::parse_start_transaction_statement(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[BeginStmt] raise ParserError {
  let tokens = self.expect_token(tokens, Keyword(Start))
  let tokens = self.expect_token(tokens, Keyword(Transaction))

  // START TRANSACTION is equivalent to BEGIN TRANSACTION
  ({ work: false, transaction: true }, tokens)
}

///|
fn Parser::parse_commit_statement(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[CommitStmt] raise ParserError {
  let tokens = self.expect_token(tokens, Keyword(Commit))

  // Parse optional WORK or TRANSACTION keywords
  let mut work = false
  let mut transaction = false
  let tokens = match tokens {
    [Keyword(Transaction), .. tokens] => {
      transaction = true
      tokens
    }
    [Keyword(Work), .. tokens] => {
      work = true
      // WORK can be followed by TRANSACTION
      match tokens {
        [Keyword(Transaction), .. tokens] => {
          transaction = true
          tokens
        }
        _ => tokens
      }
    }
    _ => tokens
  }
  ({ work, transaction }, tokens)
}

///|
fn Parser::parse_rollback_statement(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[RollbackStmt] raise ParserError {
  let tokens = self.expect_token(tokens, Keyword(Rollback))

  // Parse optional WORK or TRANSACTION keywords
  let mut work = false
  let mut transaction = false
  let mut savepoint : String? = None
  let tokens = match tokens {
    [Keyword(Transaction), .. tokens] => {
      transaction = true
      tokens
    }
    [Keyword(Work), .. tokens] => {
      work = true
      // WORK can be followed by TRANSACTION
      match tokens {
        [Keyword(Transaction), .. tokens] => {
          transaction = true
          tokens
        }
        _ => tokens
      }
    }
    _ => tokens
  }

  // Parse optional TO [SAVEPOINT] savepoint_name
  let tokens = match tokens {
    [Keyword(To), Keyword(Savepoint), Identifier(name), .. tokens] => {
      savepoint = Option::Some(name)
      tokens
    }
    [Keyword(To), Identifier(name), .. tokens] => {
      savepoint = Option::Some(name)
      tokens
    }
    _ => tokens
  }
  ({ work, transaction, savepoint }, tokens)
}

///|
fn Parser::parse_savepoint_statement(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[SavepointStmt] raise ParserError {
  let tokens = self.expect_token(tokens, Keyword(Savepoint))
  let (name, tokens) = match tokens {
    [Identifier(name), .. tokens] => (name, tokens)
    [token, .. _tokens] =>
      raise UnexpectedTokenMessageError(token, "expected savepoint name")
    [] =>
      raise InternalBug("parse_savepoint_statement: unexpected end of tokens")
  }
  ({ name, }, tokens)
}

///|
fn Parser::parse_release_savepoint_statement(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[ReleaseSavepointStmt] raise ParserError {
  let tokens = self.expect_token(tokens, Keyword(Release))

  // Parse optional SAVEPOINT keyword
  let mut savepoint_keyword = false
  let tokens = match tokens {
    [Keyword(Savepoint), .. tokens] => {
      savepoint_keyword = true
      tokens
    }
    _ => tokens
  }
  let (name, tokens) = match tokens {
    [Identifier(name), .. tokens] => (name, tokens)
    [token, .. _tokens] =>
      raise UnexpectedTokenMessageError(token, "expected savepoint name")
    [] =>
      raise InternalBug(
        "parse_release_savepoint_statement: unexpected end of tokens",
      )
  }
  ({ savepoint_keyword, name }, tokens)
}

///|
// TCL statement tests

test "BEGIN statement" {
  let tokens = "BEGIN;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|BEGIN;
    ),
  )
}

///|
test "BEGIN WORK statement" {
  let tokens = "BEGIN WORK;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|BEGIN WORK;
    ),
  )
}

///|
test "BEGIN TRANSACTION statement" {
  let tokens = "BEGIN TRANSACTION;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|BEGIN TRANSACTION;
    ),
  )
}

///|
test "START TRANSACTION statement" {
  let tokens = "START TRANSACTION;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|BEGIN TRANSACTION;
    ),
  )
}

///|
test "COMMIT statement" {
  let tokens = "COMMIT;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|COMMIT;
    ),
  )
}

///|
test "COMMIT WORK statement" {
  let tokens = "COMMIT WORK;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|COMMIT WORK;
    ),
  )
}

///|
test "ROLLBACK statement" {
  let tokens = "ROLLBACK;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|ROLLBACK;
    ),
  )
}

///|
test "ROLLBACK TO SAVEPOINT statement" {
  let tokens = "ROLLBACK TO SAVEPOINT sp1;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|ROLLBACK TO SAVEPOINT sp1;
    ),
  )
}

///|
test "SAVEPOINT statement" {
  let tokens = "SAVEPOINT sp1;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SAVEPOINT sp1;
    ),
  )
}

///|
test "RELEASE SAVEPOINT statement" {
  let tokens = "RELEASE SAVEPOINT sp1;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|RELEASE SAVEPOINT sp1;
    ),
  )
}
