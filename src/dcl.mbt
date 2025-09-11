///|
// DCL (Data Control Language) parsing functions

///|
fn Parser::parse_grant_statement(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[GrantStmt] raise ParserError {
  let tokens = self.expect_token(tokens, Keyword(Grant))

  // Parse privileges
  let (privileges, tokens) = self.parse_privilege_list(tokens)

  // Parse ON
  let tokens = self.expect_token(tokens, Keyword(On))

  // Parse objects (tables, views, etc.)
  let (objects, tokens) = self.parse_object_name_list(tokens)

  // Parse TO
  let tokens = self.expect_token(tokens, Keyword(To))

  // Parse grantees (users/roles)
  let (grantees, tokens) = self.parse_grantee_list(tokens)

  // Parse optional WITH GRANT OPTION
  let (with_grant_option, tokens) = match tokens {
    [Keyword(With), Keyword(Grant), Keyword(Option), .. tokens] =>
      (true, tokens)
    _ => (false, tokens)
  }
  ({ privileges, objects, grantees, with_grant_option }, tokens)
}

///|
fn Parser::parse_revoke_statement(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[RevokeStmt] raise ParserError {
  let tokens = self.expect_token(tokens, Keyword(Revoke))

  // Parse optional GRANT OPTION FOR
  let (grant_option_for, tokens) = match tokens {
    [Keyword(Grant), Keyword(Option), Keyword(For), .. tokens] => (true, tokens)
    _ => (false, tokens)
  }

  // Parse privileges
  let (privileges, tokens) = self.parse_privilege_list(tokens)

  // Parse ON
  let tokens = self.expect_token(tokens, Keyword(On))

  // Parse objects (tables, views, etc.)
  let (objects, tokens) = self.parse_object_name_list(tokens)

  // Parse FROM
  let tokens = self.expect_token(tokens, Keyword(From))

  // Parse grantees (users/roles)
  let (grantees, tokens) = self.parse_grantee_list(tokens)

  // Parse optional RESTRICT | CASCADE
  let (cascade, tokens) = match tokens {
    [Keyword(Restrict), .. tokens] => (Some(RevokeOption::Restrict), tokens)
    [Keyword(Cascade), .. tokens] => (Some(RevokeOption::Cascade), tokens)
    _ => (None, tokens)
  }
  ({ grant_option_for, privileges, objects, grantees, cascade }, tokens)
}

///|
fn Parser::parse_privilege_list(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[Array[Privilege]] raise ParserError {
  let privileges = []

  // Parse first privilege
  let (privilege, tokens) = self.parse_privilege(tokens)
  privileges.push(privilege)

  // Parse additional privileges separated by commas
  let tokens = loop tokens {
    [Comma, .. rest_tokens] => {
      let (privilege, tokens) = self.parse_privilege(rest_tokens)
      privileges.push(privilege)
      continue tokens
    }
    tokens => break tokens
  }
  (privileges, tokens)
}

///|
fn Parser::parse_privilege(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[Privilege] raise ParserError {
  match tokens {
    [Keyword(All), .. tokens] => {
      // Check for optional PRIVILEGES keyword
      let tokens = match tokens {
        [Keyword(Privileges), .. tokens] => tokens
        _ => tokens
      }
      (Privilege::All, tokens)
    }
    [Keyword(Select), .. tokens] => {
      let (columns, tokens) = self.parse_optional_column_list(tokens)
      (Privilege::Select(columns), tokens)
    }
    [Keyword(Insert), .. tokens] => {
      let (columns, tokens) = self.parse_optional_column_list(tokens)
      (Privilege::Insert(columns), tokens)
    }
    [Keyword(Update), .. tokens] => {
      let (columns, tokens) = self.parse_optional_column_list(tokens)
      (Privilege::Update(columns), tokens)
    }
    [Keyword(Delete), .. tokens] => (Privilege::Delete, tokens)
    [Keyword(References), .. tokens] => {
      let (columns, tokens) = self.parse_optional_column_list(tokens)
      (Privilege::References(columns), tokens)
    }
    [Keyword(Create), .. tokens] => (Privilege::Create, tokens)
    [Keyword(Drop), .. tokens] => (Privilege::Drop, tokens)
    [Keyword(Alter), .. tokens] => (Privilege::Alter, tokens)
    [Keyword(Index), .. tokens] => (Privilege::Index, tokens)
    [Keyword(Usage), .. tokens] => (Privilege::Usage, tokens)
    [Keyword(Execute), .. tokens] => (Privilege::Execute, tokens)
    [Keyword(Connect), .. tokens] => (Privilege::Connect, tokens)
    [Keyword(Temporary), .. tokens] => (Privilege::Temporary, tokens)
    [Keyword(Temp), .. tokens] => (Privilege::Temporary, tokens)
    [token, .. _tokens] =>
      raise UnexpectedTokenMessageError(token, "expected privilege name")
    [] => raise InternalBug("parse_privilege: unexpected end of tokens")
  }
}

///|
fn Parser::parse_optional_column_list(
  _self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[Array[String]?] raise ParserError {
  match tokens {
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
          raise UnexpectedTokenMessageError(token, "expected column name")
        [] =>
          raise InternalBug(
            "parse_optional_column_list: unexpected end of tokens",
          )
      }
      (Some(columns), tokens)
    }
    _ => (None, tokens)
  }
}

///|
fn Parser::parse_object_name_list(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[Array[ObjectName]] raise ParserError {
  let objects = []

  // Parse first object name
  let (obj_name, tokens) = self.parse_object_name(tokens)
  objects.push(obj_name)

  // Parse additional object names separated by commas
  let tokens = loop tokens {
    [Comma, .. rest_tokens] => {
      let (obj_name, tokens) = self.parse_object_name(rest_tokens)
      objects.push(obj_name)
      continue tokens
    }
    tokens => break tokens
  }
  (objects, tokens)
}

///|
fn Parser::parse_grantee_list(
  _self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[Array[String]] raise ParserError {
  let grantees = []

  // Parse first grantee
  let (grantee, tokens) = match tokens {
    [Identifier(name), .. tokens] => (name, tokens)
    [StringLiteral(name), .. tokens] => (name, tokens)
    [token, .. _tokens] =>
      raise UnexpectedTokenMessageError(token, "expected user or role name")
    [] => raise InternalBug("parse_grantee_list: unexpected end of tokens")
  }
  grantees.push(grantee)

  // Parse additional grantees separated by commas
  let tokens = loop tokens {
    [Comma, .. rest_tokens] => {
      let (grantee, tokens) = match rest_tokens {
        [Identifier(name), .. tokens] => (name, tokens)
        [StringLiteral(name), .. tokens] => (name, tokens)
        [token, .. _tokens] =>
          raise UnexpectedTokenMessageError(token, "expected user or role name")
        [] =>
          raise InternalBug(
            "parse_grantee_list: unexpected end of tokens after comma",
          )
      }
      grantees.push(grantee)
      continue tokens
    }
    tokens => break tokens
  }
  (grantees, tokens)
}

///|
// DCL statement tests

test "GRANT SELECT statement" {
  let tokens = "GRANT SELECT ON users TO alice;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|GRANT SELECT ON users TO alice;
    ),
  )
}

///|
test "GRANT multiple privileges statement" {
  let tokens = "GRANT SELECT, INSERT, UPDATE ON users TO alice, bob;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|GRANT SELECT, INSERT, UPDATE ON users TO alice, bob;
    ),
  )
}

///|
test "GRANT with column specification" {
  let tokens = "GRANT SELECT (name, email), UPDATE (email) ON users TO alice;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|GRANT SELECT(name, email), UPDATE(email) ON users TO alice;
    ),
  )
}

///|
test "GRANT ALL PRIVILEGES statement" {
  let tokens = "GRANT ALL PRIVILEGES ON users TO alice WITH GRANT OPTION;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|GRANT ALL PRIVILEGES ON users TO alice WITH GRANT OPTION;
    ),
  )
}

///|
test "REVOKE SELECT statement" {
  let tokens = "REVOKE SELECT ON users FROM alice;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|REVOKE SELECT ON users FROM alice;
    ),
  )
}

///|
test "REVOKE with CASCADE" {
  let tokens = "REVOKE ALL PRIVILEGES ON users FROM alice CASCADE;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|REVOKE ALL PRIVILEGES ON users FROM alice CASCADE;
    ),
  )
}

///|
test "REVOKE GRANT OPTION FOR" {
  let tokens = "REVOKE GRANT OPTION FOR SELECT ON users FROM alice RESTRICT;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|REVOKE GRANT OPTION FOR SELECT ON users FROM alice RESTRICT;
    ),
  )
}
