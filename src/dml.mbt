///|
fn parse_select_statement(
  tokens : ArrayView[Token]
) -> Parser[SelectStmt] raise ParserError {
  let tokens = expect_token(tokens, Keyword(Select))
  let (projections, tokens) = parse_projections(tokens)
  let (from, tokens) = parse_table_refs(tokens)
  let (where_clause, tokens) = match tokens {
    [Keyword(Where), .. tokens] => {
      let (expr, tokens) = parse_expr(tokens)
      (Some(expr), tokens)
    }
    _ => (None, tokens)
  }
  let (group_by, tokens) = match tokens {
    [Keyword(Group), Keyword(By), .. tokens] => parse_group_by(tokens)
    _ => ([], tokens)
  }
  let (having, tokens) = match tokens {
    [Keyword(Having), .. tokens] => {
      let (expr, tokens) = parse_expr(tokens)
      (Some(expr), tokens)
    }
    _ => (None, tokens)
  }
  let (order_by, tokens) = match tokens {
    [Keyword(Order), Keyword(By), .. tokens] => parse_order_by(tokens)
    _ => ([], tokens)
  }
  let (limit, tokens) = match tokens {
    [Keyword(Limit), .. tokens] => {
      let (expr, tokens) = parse_expr(tokens)
      (Some(expr), tokens)
    }
    _ => (None, tokens)
  }
  let (offset, tokens) = match tokens {
    [Keyword(Offset), .. tokens] => {
      let (expr, tokens) = parse_expr(tokens)
      (Some(expr), tokens)
    }
    _ => (None, tokens)
  }
  (
    {
      projections,
      from,
      where_clause,
      group_by,
      having,
      order_by,
      limit,
      offset,
    },
    tokens,
  )
}

///|
fn parse_aliasing(
  tokens : ArrayView[Token]
) -> Parser[TableAlias?] raise ParserError {
  let tokens = match tokens {
    [Keyword(As), .. tokens] => tokens
    tokens => tokens
  }
  match tokens {
    [Identifier(name), .. tokens] => {
      let columns = []
      let tokens = match tokens {
        [LParen, .. tokens] =>
          loop tokens {
            [Identifier(col_name), Comma, .. tokens] => {
              columns.push(col_name)
              continue tokens
            }
            [Identifier(col_name), RParen, .. tokens] => {
              columns.push(col_name)
              break tokens
            }
            [unknown, .. _tokens] =>
              raise UnexpectedTokenMessageError(
                unknown, "expected column name in aliasing",
              )
            [] =>
              raise ParserError::InternalBug(
                "parse_aliasing: unexpected end of tokens",
              )
          }
        tokens => tokens
      }
      (Some({ name, columns }), tokens)
    }
    tokens => (None, tokens)
  }
}

///|
fn parse_projections(
  tokens : ArrayView[Token]
) -> Parser[Array[Projection]] raise ParserError {
  let projections = []
  loop tokens {
    [Mul, .. tokens] => {
      projections.push(Projection::Wildcard)
      match tokens {
        [Comma, .. tokens] => continue tokens
        _ => break (projections, tokens)
      }
    }
    tokens => {
      let (expr, tokens) = parse_expr(tokens)
      let (optional_alias, tokens) = match tokens {
        [Keyword(As), Identifier(alias_name), .. tokens] =>
          (Some(alias_name), tokens)
        [Identifier(alias_name), .. tokens] => (Some(alias_name), tokens)
        _ => (None, tokens)
      }
      match optional_alias {
        Some(alias_name) =>
          projections.push(Projection::AliasedExpr(expr, alias_name))
        None => projections.push(Projection::UnamedExpr(expr))
      }
      match tokens {
        [Comma, .. tokens] => continue tokens
        _ => break (projections, tokens)
      }
    }
  }
}

///|
fn parse_expr(tokens : ArrayView[Token]) -> Parser[Expr] raise ParserError {
  parse_binary_expr(tokens, 0)
}

///|
fn get_next_bp(tokens : ArrayView[Token]) -> Int {
  match tokens {
    [token, .. _tokens] if try_binary_operator(token) is Some(op) =>
      op.get_precedence().value()
    [Keyword(Like), .. _tokens]
    | [Keyword(ILike), .. _tokens]
    | [Keyword(Not), Keyword(Like), .. _tokens]
    | [Keyword(Not), Keyword(ILike), .. _tokens] => Precedence::Like.value()
    [Keyword(Between), .. _tokens]
    | [Keyword(In), .. _tokens]
    | [Keyword(Not), Keyword(Between), .. _tokens]
    | [Keyword(Not), Keyword(In), .. _tokens] => Precedence::Between.value()
    _ => 0
  }
}

///|
fn parse_binary_expr(
  tokens : ArrayView[Token],
  min_bp : Int
) -> Parser[Expr] raise ParserError {
  let mut expr_tokens = parse_primary_expr(tokens)
  for {
    let expr = expr_tokens.0
    let tokens = expr_tokens.1
    let next_bp = get_next_bp(tokens)
    if next_bp <= min_bp {
      return (expr, tokens)
    }
    expr_tokens = parse_infix(tokens, expr, next_bp)
  }
}

///|
fn parse_infix(
  tokens : ArrayView[Token],
  left : Expr,
  min_bp : Int
) -> Parser[Expr] raise ParserError {
  match tokens {
    [token, .. tokens] if try_binary_operator(token) is Some(op) => {
      let (right, tokens) = parse_binary_expr(tokens, min_bp)
      let expr = Expr::BinaryOperation(left, op, right)
      (expr, tokens)
    }
    [Keyword(Like), .. tokens] => {
      let (right, tokens) = parse_binary_expr(tokens, Precedence::Like.value())
      let expr = Expr::Like(positive=true, left, right)
      (expr, tokens)
    }
    [Keyword(ILike), .. tokens] => {
      let (right, tokens) = parse_binary_expr(tokens, Precedence::Like.value())
      let expr = Expr::ILike(positive=true, left, right)
      (expr, tokens)
    }
    [Keyword(Not), Keyword(Like), .. tokens] => {
      let (right, tokens) = parse_binary_expr(tokens, Precedence::Like.value())
      let expr = Expr::Like(positive=false, left, right)
      (expr, tokens)
    }
    [Keyword(Not), Keyword(ILike), .. tokens] => {
      let (right, tokens) = parse_binary_expr(tokens, Precedence::Like.value())
      let expr = Expr::ILike(positive=false, left, right)
      (expr, tokens)
    }
    [Keyword(Between), .. tokens] => parse_between_expr(tokens, left, true)
    [Keyword(Not), Keyword(Between), .. tokens] =>
      parse_between_expr(tokens, left, false)
    [Keyword(In), .. tokens] => parse_in_expr(tokens, left, true)
    [Keyword(Not), Keyword(In), .. tokens] => parse_in_expr(tokens, left, false)
    _ => (left, tokens)
  }
}

///|
fn try_binary_operator(token : Token) -> BinaryOperator? {
  match token {
    Token::Mul => Some(BinaryOperator::Mul)
    Token::Plus => Some(BinaryOperator::Plus)
    Token::Minus => Some(BinaryOperator::Minus)
    Token::Div => Some(BinaryOperator::Div)
    Token::Mod => Some(BinaryOperator::Mod)
    Token::Eq => Some(BinaryOperator::Eq)
    Token::Neq => Some(BinaryOperator::Neq)
    Token::Lt => Some(BinaryOperator::Lt)
    Token::Gt => Some(BinaryOperator::Gt)
    Token::LtEq => Some(BinaryOperator::LtEq)
    Token::GtEq => Some(BinaryOperator::GtEq)
    Token::Spaceship => Some(BinaryOperator::Spaceship)
    Keyword(And) => Some(BinaryOperator::And)
    Keyword(Or) => Some(BinaryOperator::Or)
    _ => None
  }
}

///|
fn parse_primary_expr(
  tokens : ArrayView[Token]
) -> Parser[Expr] raise ParserError {
  match tokens {
    [Minus as op, .. tokens] | [Plus as op, .. tokens] => {
      let (expr, tokens) = parse_binary_expr(
        tokens,
        Precedence::MulDivMod.value(),
      )
      let op = if op == Minus { UnaryOperator::Minus } else { Plus }
      (UnaryOperation(op, expr), tokens)
    }
    [Boolean(b), .. tokens] => (Literal(Literal::Boolean(b)), tokens)
    [Keyword(Null), .. tokens] => (Literal(Literal::Null), tokens)
    [Number(n), .. tokens] =>
      if n.contains_char('.') {
        let v = @strconv.parse_double(n) catch {
          StrConvError(e) =>
            raise ParserError::InternalBug("parse_primary_expr: \{e}")
        }
        (Literal(Literal::Double(v)), tokens)
      } else {
        let v = @strconv.parse_int(n) catch {
          StrConvError(e) =>
            raise ParserError::InternalBug("parse_primary_expr: \{e}")
        }
        (Literal(Literal::Integer(v)), tokens)
      }
    [StringLiteral(s), .. tokens] => (Literal(Literal::String(s)), tokens)
    [Keyword(Date), .. tokens] => parse_date_expr(tokens)
    [Keyword(Interval), .. tokens] => parse_interval_expr(tokens)
    [Keyword(Extract), .. tokens] => parse_extract_expr(tokens)
    [Keyword(Substring), .. tokens] => parse_substring_expr(tokens)
    [Identifier(name), LParen, .. tokens] => {
      let args = []
      let (dup, tokens) = match tokens {
        [Keyword(Distinct), .. tokens] =>
          (Some(DuplicateTreatment::Distinct), tokens)
        [Keyword(All), .. tokens] => (Some(DuplicateTreatment::All), tokens)
        tokens => (None, tokens)
      }
      loop tokens {
        [RParen, .. tokens] => break (FunctionCall(name, dup, args), tokens)
        tokens => {
          let (arg, tokens) = parse_expr(tokens)
          args.push(arg)
          match tokens {
            [Comma, .. tokens] => continue tokens
            [RParen, .. tokens] => break (FunctionCall(name, dup, args), tokens)
            _ =>
              raise UnexpectedTokenMessageError(
                tokens[0],
                "expected ',' or ')'",
              )
          }
        }
      }
    }
    [Identifier(name), Period, .. tokens] => {
      let parts = [name]
      loop tokens {
        [Identifier(part), Period, .. tokens] => {
          parts.push(part)
          continue tokens
        }
        [Identifier(part), .. tokens] => {
          parts.push(part)
          break (CompoundIdentifier(parts), tokens)
        }
        [token, .. _tokens] =>
          raise UnexpectedTokenMessageError(
            token, "expected another identifier after '.'",
          )
        [] =>
          raise ParserError::InternalBug(
            "parse_primary_expr: unexpected end of tokens",
          )
      }
    }
    [Identifier(name), .. tokens] => (Identifier(name), tokens)
    [Keyword(Exists), LParen, .. tokens] => {
      let (sub_query, tokens) = parse_select_statement(tokens)
      match tokens {
        [RParen, .. tokens] => (Expr::Exists(positive=true, sub_query), tokens)
        [token, .. _tokens] =>
          raise UnexpectedTokenMessageError(token, "expected ')'")
        [] =>
          raise ParserError::InternalBug(
            "parse_primary_expr: unexpected end of tokens",
          )
      }
    }
    [Keyword(Not), Keyword(Exists), LParen, .. tokens] => {
      let (sub_query, tokens) = parse_select_statement(tokens)
      match tokens {
        [RParen, .. tokens] => (Expr::Exists(positive=false, sub_query), tokens)
        [token, .. _tokens] =>
          raise UnexpectedTokenMessageError(token, "expected ')'")
        [] =>
          raise ParserError::InternalBug(
            "parse_primary_expr: unexpected end of tokens",
          )
      }
    }
    [Keyword(Not), .. tokens] => {
      let (expr, tokens) = parse_binary_expr(
        tokens,
        Precedence::UnaryNot.value(),
      )
      (Expr::UnaryOperation(UnaryOperator::Not, expr), tokens)
    }
    [Keyword(Case), .. tokens] => parse_case_expr(tokens)
    [Token::LParen, .. tokens] => {
      let (expr, tokens) = try parse_select_statement(tokens) catch {
        _ => parse_expr(tokens)
      } noraise {
        (stmt, tokens) => (Expr::SubQuery(stmt), tokens)
      }
      let tokens = expect_token(tokens, RParen)
      (expr, tokens)
    }
    [Token::Mul, .. tokens] => (Expr::Wildcard, tokens)
    [token, .. _tokens] =>
      raise UnimplementedError("parse_primary_expr: \{token}")
    [] =>
      raise ParserError::InternalBug(
        "parse_primary_expr: unexpected end of tokens",
      )
  }
}

///|
fn parse_table_refs(
  tokens : ArrayView[Token]
) -> Parser[Array[TableRef]] raise ParserError {
  let tokens = expect_token(tokens, Keyword(From))
  let table_refs = []
  loop tokens {
    tokens => {
      let (table_ref, tokens) = parse_table_ref(tokens)
      table_refs.push(table_ref)
      match tokens {
        [Comma, .. tokens] => continue tokens
        tokens => break (table_refs, tokens)
      }
    }
  }
}

///|
fn parse_table_ref(
  tokens : ArrayView[Token]
) -> Parser[TableRef] raise ParserError {
  let (factor, tokens) = parse_table_factor(tokens)
  let joins = []
  let tokens = loop tokens {
    tokens if tokens[0] is Keyword(Join) ||
      tokens[0] is Keyword(Left) ||
      tokens[0] is Keyword(Right) ||
      tokens[0] is Keyword(Full) ||
      tokens[0] is Keyword(Inner) => {
      let (join_operator_maker, tokens) = match tokens {
        [Keyword(Join), .. tokens] => (JoinOperator::Join(_), tokens)
        [Keyword(Left), Keyword(Join), .. tokens] =>
          (JoinOperator::Left(_), tokens)
        [Keyword(Left), Keyword(Outer), Keyword(Join), .. tokens] =>
          (JoinOperator::LeftOuter(_), tokens)
        [Keyword(Right), Keyword(Join), .. tokens] =>
          (JoinOperator::Right(_), tokens)
        [Keyword(Right), Keyword(Outer), Keyword(Join), .. tokens] =>
          (JoinOperator::RightOuter(_), tokens)
        [Keyword(Full), Keyword(Join), .. tokens] =>
          (JoinOperator::Full(_), tokens)
        [Keyword(Full), Keyword(Outer), Keyword(Join), .. tokens] =>
          (JoinOperator::FullOuter(_), tokens)
        [Keyword(Inner), Keyword(Join), .. tokens] =>
          (JoinOperator::Inner(_), tokens)
        _ =>
          raise UnexpectedTokenMessageError(
            tokens[0],
            "expected 'JOIN', 'LEFT JOIN', 'LEFT OUTER JOIN', 'RIGHT JOIN', 'RIGHT OUTER JOIN', 'FULL OUTER JOIN', 'INNER JOIN'",
          )
      }
      let (table_ref, tokens) = parse_table_ref(tokens)
      match tokens {
        [Keyword(On), .. tokens] => {
          let (constraint, tokens) = parse_expr(tokens)
          joins.push({
            join_operator: join_operator_maker(On(constraint)),
            table_ref,
          })
          continue tokens
        }
        [Keyword(Using), .. tokens] => {
          let columns = []
          let tokens = match tokens {
            [LParen, .. tokens] =>
              loop tokens {
                [Identifier(col_name), Comma, .. tokens] => {
                  columns.push(col_name)
                  continue tokens
                }
                [Identifier(col_name), RParen, .. tokens] => {
                  columns.push(col_name)
                  break tokens
                }
                [unknown, .. _tokens] =>
                  raise UnexpectedTokenMessageError(
                    unknown, "expected column name in USING clause",
                  )
                [] =>
                  raise ParserError::InternalBug(
                    "parse_table_ref: unexpected end of tokens",
                  )
              }
            [token, .. _tokens] =>
              raise UnexpectedTokenMessageError(
                token, "expected '(' after 'USING'",
              )
            [] =>
              raise ParserError::InternalBug(
                "parse_table_ref: unexpected end of tokens",
              )
          }
          joins.push({
            join_operator: join_operator_maker(Using(columns)),
            table_ref,
          })
          continue tokens
        }
        tokens => {
          joins.push({ join_operator: join_operator_maker(None), table_ref })
          continue tokens
        }
      }
    }
    [Keyword(Cross), Keyword(Join), .. tokens] => {
      let (table_ref, tokens) = parse_table_ref(tokens)
      joins.push({ join_operator: JoinOperator::Cross, table_ref })
      continue tokens
    }
    tokens => break tokens
  }
  ({ factor, joins }, tokens)
}

///|
fn parse_table_factor(
  tokens : ArrayView[Token]
) -> Parser[TableFactor] raise ParserError {
  match tokens {
    [Identifier(name), .. tokens] => {
      let (optional_alias, tokens) = parse_aliasing(tokens)
      (TableFactor::Column(name, optional_alias), tokens)
    }
    [StringLiteral(name), .. tokens] => {
      let (optional_alias, tokens) = parse_aliasing(tokens)
      (TableFactor::Column(name, optional_alias), tokens)
    }
    [Token::LParen, .. tokens] => {
      let (sub_query, tokens) = parse_select_statement(tokens)
      let tokens = expect_token(tokens, RParen)
      let (optional_alias, tokens) = parse_aliasing(tokens)
      (TableFactor::SubQuery(sub_query, optional_alias), tokens)
    }
    [token, .. _tokens] =>
      raise UnexpectedTokenMessageError(
        token, "expected a table name or subquery",
      )
    [] =>
      raise ParserError::InternalBug(
        "parse_table_factor: unexpected end of tokens",
      )
  }
}

///|
fn parse_group_by(
  tokens : ArrayView[Token]
) -> Parser[Array[Expr]] raise ParserError {
  let group_by = []
  loop tokens {
    tokens => {
      let (expr, tokens) = parse_expr(tokens)
      group_by.push(expr)
      match tokens {
        [Comma, .. tokens] => continue tokens
        _ => break (group_by, tokens)
      }
    }
  }
}

///|
fn parse_order_by(
  tokens : ArrayView[Token]
) -> Parser[Array[OrderByExpr]] raise ParserError {
  let order_by = []
  loop tokens {
    tokens => {
      let (order_by_expr, tokens) = parse_order_by_expr(tokens)
      order_by.push(order_by_expr)
      match tokens {
        [Comma, .. tokens] => continue tokens
        _ => break (order_by, tokens)
      }
    }
  }
}

///|
fn parse_order_by_expr(
  tokens : ArrayView[Token]
) -> Parser[OrderByExpr] raise ParserError {
  let (expr, tokens) = parse_expr(tokens)
  let (asc, tokens) = match tokens {
    [Keyword(Asc), .. tokens] => (Some(true), tokens)
    [Keyword(Desc), .. tokens] => (Some(false), tokens)
    _ => (None, tokens)
  }
  let (nulls_first, tokens) = match tokens {
    [Keyword(Nulls), Keyword(First), .. tokens] => (Some(true), tokens)
    [Keyword(Nulls), Keyword(Last), .. tokens] => (Some(false), tokens)
    _ => (None, tokens)
  }
  ({ expr, asc, nulls_first }, tokens)
}

///|
fn parse_date_expr(tokens : ArrayView[Token]) -> Parser[Expr] raise ParserError {
  match tokens {
    [StringLiteral(s), .. tokens] => (Expr::Datetime(s), tokens)
    [token, .. _tokens] =>
      raise UnexpectedTokenMessageError(
        token, "expected a string literal after 'DATE'",
      )
    [] =>
      raise ParserError::InternalBug(
        "parse_date_expr: unexpected end of tokens",
      )
  }
}

///|
fn parse_interval_expr(
  tokens : ArrayView[Token]
) -> Parser[Expr] raise ParserError {
  match tokens {
    [StringLiteral(s), .. tokens] => {
      let (qualifier, tokens) = parse_interval_qualifier(tokens)
      (Expr::Interval(s, qualifier), tokens)
    }
    [token, .. _tokens] =>
      raise UnexpectedTokenMessageError(
        token, "expected a string literal after 'INTERVAL'",
      )
    [] =>
      raise ParserError::InternalBug(
        "parse_interval_expr: unexpected end of tokens",
      )
  }
}

///|
fn parse_extract_expr(
  tokens : ArrayView[Token]
) -> Parser[Expr] raise ParserError {
  match tokens {
    [LParen, .. tokens] => {
      let (field, tokens) = parse_primary_datetime_field(tokens)
      let tokens = expect_token(tokens, Keyword(From))
      let (expr, tokens) = parse_expr(tokens)
      let tokens = expect_token(tokens, RParen)
      (Expr::Extract(field, expr), tokens)
    }
    [token, .. _tokens] =>
      raise UnexpectedTokenMessageError(token, "expected 'EXTRACT('")
    [] =>
      raise ParserError::InternalBug(
        "parse_extract_expr: unexpected end of tokens",
      )
  }
}

///|
fn parse_case_expr(tokens : ArrayView[Token]) -> Parser[Expr] raise ParserError {
  let when_then_clauses = []
  let mut else_expr : Expr? = None
  let (operand, tokens) : (Expr?, _) = match tokens {
    [Keyword(When), ..] => (None, tokens)
    tokens => {
      let (expr, tokens) = parse_expr(tokens)
      (Some(expr), tokens)
    }
  }
  loop tokens {
    [Keyword(When), .. tokens] => {
      let (condition, tokens) = parse_expr(tokens)
      let tokens = expect_token(tokens, Keyword(Then))
      let (result, tokens) = parse_expr(tokens)
      when_then_clauses.push((condition, result))
      continue tokens
    }
    [Keyword(Else), .. tokens] => {
      if else_expr is Some(_e) {
        raise MultipleElseInCaseExprError
      }
      let (expr, tokens) = parse_expr(tokens)
      else_expr = Some(expr)
      continue tokens
    }
    [Keyword(End), .. tokens] => {
      let case_expr = Expr::Case({ when_then_clauses, else_expr, operand })
      break (case_expr, tokens)
    }
    [token, .. _tokens] =>
      raise UnexpectedTokenMessageError(
        token, "expected 'WHEN', 'ELSE', or 'END'",
      )
    [] =>
      raise ParserError::InternalBug(
        "parse_case_expr: unexpected end of tokens",
      )
  }
}

///|
fn parse_interval_qualifier(
  tokens : ArrayView[Token]
) -> Parser[IntervalQualifier] raise ParserError {
  let (field1, tokens) = parse_primary_datetime_field(tokens)
  match tokens {
    [Keyword(To), .. tokens] => {
      let field2 = parse_primary_datetime_field(tokens)
      match field2 {
        (field2, tokens) => (IntervalQualifier::Range(field1, field2), tokens)
      }
    }
    _ => (IntervalQualifier::Single(field1), tokens)
  }
}

///|
fn parse_primary_datetime_field(
  tokens : ArrayView[Token]
) -> Parser[PrimaryDatetimeField] raise ParserError {
  match tokens {
    [keyword, .. tokens] if datetime_unit_from_keyword(keyword) is Some(field) => {
      let (precision, tokens) = match tokens {
        [LParen, Number(n), RParen, .. tokens] => {
          let p = @strconv.parse_int(n) catch {
            StrConvError(e) =>
              raise ParserError::InternalBug(
                "parse_primary_datetime_field: \{e}",
              )
          }
          (Some(p), tokens)
        }
        tokens => (None, tokens)
      }
      ({ field, precision }, tokens)
    }
    [token, .. _tokens] =>
      raise UnexpectedTokenMessageError(
        token, "expected a datetime unit keyword (e.g., YEAR, MONTH, DAY, etc.)",
      )
    [] =>
      raise ParserError::InternalBug(
        "parse_primary_datetime_field: unexpected end of tokens",
      )
  }
}

///|
fn parse_between_expr(
  tokens : ArrayView[Token],
  left : Expr,
  positive : Bool
) -> Parser[Expr] raise ParserError {
  let (low, tokens) = parse_binary_expr(tokens, Precedence::Between.value())
  match tokens {
    [Keyword(And), .. tokens] => {
      let (hi, tokens) = parse_binary_expr(tokens, Precedence::Between.value())
      (Expr::Between(positive~, left, low, hi), tokens)
    }
    [token, .. _tokens] =>
      raise UnexpectedTokenMessageError(token, "expected 'AND'")
    [] =>
      raise ParserError::InternalBug(
        "parse_between_expr: unexpected end of tokens",
      )
  }
}

///|
fn parse_in_expr(
  tokens : ArrayView[Token],
  left : Expr,
  positive : Bool
) -> Parser[Expr] raise ParserError {
  let tokens = expect_token(tokens, LParen)
  try parse_select_statement(tokens) catch {
    _ => {
      let items = []
      let tokens = loop tokens {
        tokens => {
          let (item, tokens) = parse_expr(tokens)
          items.push(item)
          match tokens {
            [Comma, .. tokens] => continue tokens
            [RParen, .. tokens] => break tokens
            [token, .. _tokens] =>
              raise UnexpectedTokenMessageError(token, "expected ',' or ')'")
            [] =>
              raise ParserError::InternalBug(
                "parse_in_expr: unexpected end of tokens",
              )
          }
        }
      }
      (Expr::InList(positive~, left, items), tokens)
    }
  } noraise {
    (stmt, tokens) =>
      match tokens {
        [RParen, .. tokens] => (Expr::InSubQuery(positive~, left, stmt), tokens)
        [token, .. _tokens] =>
          raise UnexpectedTokenMessageError(token, "expected ')'")
        [] =>
          raise ParserError::InternalBug(
            "parse_in_expr: unexpected end of tokens",
          )
      }
  }
}

///|
fn datetime_unit_from_keyword(keyword : Token) -> DatetimeUnit? {
  match keyword {
    Keyword(Year) => Some(Year)
    Keyword(Month) => Some(Month)
    Keyword(Day) => Some(Day)
    Keyword(Hour) => Some(Hour)
    Keyword(Minute) => Some(Minute)
    Keyword(Second) => Some(Second)
    _ => None
  }
}

///|
fn parse_substring_expr(
  tokens : ArrayView[Token]
) -> Parser[Expr] raise ParserError {
  let tokens = expect_token(tokens, LParen)
  let (expr, tokens) = parse_expr(tokens)
  let (start, len, tokens) = match tokens {
    [Keyword(From), .. tokens] => {
      let (start_expr, tokens) = parse_expr(tokens)
      let (len_expr, tokens) = match tokens {
        [Keyword(For), .. tokens] => {
          let (len_expr, tokens) = parse_expr(tokens)
          (Some(len_expr), tokens)
        }
        _ => (None, tokens)
      }
      (Some(start_expr), len_expr, tokens)
    }
    [Comma, .. tokens] => {
      let (start_expr, tokens) = parse_expr(tokens)
      let (len_expr, tokens) = match tokens {
        [Comma, .. tokens] => {
          let (len_expr, tokens) = parse_expr(tokens)
          (Some(len_expr), tokens)
        }
        _ => (None, tokens)
      }
      (Some(start_expr), len_expr, tokens)
    }
    tokens => (None, None, tokens)
  }
  let tokens = expect_token(tokens, RParen)
  (Substring(expr, start, len), tokens)
}

///|
test "Parse select with two columns" {
  let tokens = "SELECT col1, col2 FROM t;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  col1,
      #|  col2
      #|FROM
      #|  t;
    ),
  )
}

///|
test "Parse select with function call" {
  let tokens = "SELECT MAX(arg1, arg2), MIN() as m FROM t;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  max(arg1, arg2),
      #|  min() AS m
      #|FROM
      #|  t;
    ),
  )
}

///|
test "Nested expression" {
  let tokens = "SELECT sum(l_extendedprice * (1 - l_discount)) FROM lineitem;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  sum(l_extendedprice * (1 - l_discount))
      #|FROM
      #|  lineitem;
    ),
  )
}

///|
test "Binary expression" {
  let tokens = "SELECT 1 + 2 * 3 FROM t;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  1 + 2 * 3
      #|FROM
      #|  t;
    ),
  )
}

///|
test "Complecated binary expression" {
  let tokens = "SELECT sum(a * (1 - b) * (2 + b)) AS c FROM t;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  sum(a * (1 - b) * (2 + b)) AS c
      #|FROM
      #|  t;
    ),
  )
}

///|
test "Selection clause" {
  let tokens = "SELECT * FROM t WHERE id = 1;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  *
      #|FROM
      #|  t
      #|WHERE
      #|  id = 1;
    ),
  )
}

///|
test "Like, ilike, not like, not ilike" {
  let tokens =
    #|SELECT 
    #|  * 
    #|FROM 
    #|  t 
    #|WHERE 
    #|  name LIKE 'test' 
    #|  AND name ILIKE 'TEST' 
    #|  AND name NOT LIKE 'test2' 
    #|  AND name NOT ILIKE 'TEST2';
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  *
      #|FROM
      #|  t
      #|WHERE
      #|  name LIKE 'test' 
      #|  AND name ILIKE 'TEST' 
      #|  AND name NOT LIKE 'test2' 
      #|  AND name NOT ILIKE 'TEST2';
    ),
  )
}

///|
test "From multiple table refs" {
  let tokens = "SELECT * FROM t1, t2;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  *
      #|FROM
      #|  t1,
      #|  t2;
    ),
  )
}

///|
test "SubQuery" {
  let tokens = "SELECT sub FROM (SELECT name FROM users WHERE active = true) AS sub;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  sub
      #|FROM
      #|  (
      #|    SELECT
      #|      name
      #|    FROM
      #|      users
      #|    WHERE
      #|      active = TRUE
      #|  ) AS sub;
    ),
  )
}

///|
test "Exists, not exists" {
  let tokens = "SELECT * FROM t WHERE EXISTS (SELECT 1 FROM t2) AND NOT EXISTS (SELECT 1 FROM t3);"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  *
      #|FROM
      #|  t
      #|WHERE
      #|  EXISTS (
      #|  SELECT
      #|      1
      #|    FROM
      #|      t2
      #|  ) 
      #|  AND NOT EXISTS (
      #|  SELECT
      #|      1
      #|    FROM
      #|      t3
      #|  );
    ),
  )
}

///|
test "Between and" {
  let tokens = "SELECT * FROM t WHERE id BETWEEN 1 AND 10;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  *
      #|FROM
      #|  t
      #|WHERE
      #|  id BETWEEN 1 AND 10;
    ),
  )
}

///|
test "Compound identifiers" {
  let tokens = "SELECT t1.col1, t2.col2 FROM t1, t2;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  t1.col1,
      #|  t2.col2
      #|FROM
      #|  t1,
      #|  t2;
    ),
  )
}

///|
test "Extract function" {
  let tokens = "SELECT EXTRACT(YEAR FROM date_col) FROM t;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  EXTRACT(YEAR FROM date_col)
      #|FROM
      #|  t;
    ),
  )
}

///|
test "Aliasing omits AS" {
  let tokens = "SELECT col1 c1, col2 FROM t;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  col1 AS c1,
      #|  col2
      #|FROM
      #|  t;
    ),
  )
}

///|
test "Case when" {
  let tokens = "SELECT CASE WHEN a > 0 THEN 'positive' WHEN a < 0 THEN 'negative' ELSE 'zero' END AS result FROM t;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  CASE
      #|    WHEN a > 0 THEN 'positive'
      #|    WHEN a < 0 THEN 'negative'
      #|    ELSE 'zero'
      #|  END AS result
      #|FROM
      #|  t;
    ),
  )
}

///|
test "Having" {
  let tokens = "SELECT col1, COUNT(*) FROM t GROUP BY col1 HAVING COUNT(*) > 1;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  col1,
      #|  count(*)
      #|FROM
      #|  t
      #|GROUP BY
      #|  col1
      #|HAVING
      #|  count(*) > 1;
    ),
  )
}

///|
test "In list" {
  let tokens = "SELECT * FROM t WHERE col1 IN (1, 2, 3);"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  *
      #|FROM
      #|  t
      #|WHERE
      #|  col1 IN (1, 2, 3);
    ),
  )
}

///|
test "In subquery" {
  let tokens = "SELECT * FROM t WHERE col1 IN (SELECT col2 FROM t2);"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  *
      #|FROM
      #|  t
      #|WHERE
      #|  col1 IN (
      #|    SELECT
      #|      col2
      #|    FROM
      #|      t2
      #|  );
    ),
  )
}

///|
test "Join with ON condition" {
  let tokens = "SELECT * FROM t1 JOIN t2 ON t1.id = t2.id;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  *
      #|FROM
      #|  t1 JOIN t2
      #|    ON t1.id = t2.id;
    ),
  )
}

///|
test "Cross join" {
  let tokens = "SELECT * FROM t1 CROSS JOIN t2;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  *
      #|FROM
      #|  t1 CROSS JOIN t2;
    ),
  )
}

///|
test "Left join" {
  let tokens = "SELECT * FROM t1 LEFT JOIN t2 ON t1.id = t2.id GROUP BY x;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  *
      #|FROM
      #|  t1 LEFT JOIN t2
      #|    ON t1.id = t2.id
      #|GROUP BY
      #|  x;
    ),
  )
}

///|
test "Right join" {
  let tokens = "SELECT * FROM t1 RIGHT JOIN t2 ON t1.id = t2.id;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  *
      #|FROM
      #|  t1 RIGHT JOIN t2
      #|    ON t1.id = t2.id;
    ),
  )
}

///|
test "Full outer join" {
  let tokens = "SELECT * FROM t1 LEFT OUTER JOIN t2 ON t1.id = t2.id;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  *
      #|FROM
      #|  t1 LEFT OUTER JOIN t2
      #|    ON t1.id = t2.id;
    ),
  )
}

///|
test "Null, true and false" {
  let tokens = "SELECT NULL, true, false FROM t1;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  NULL,
      #|  TRUE,
      #|  FALSE
      #|FROM
      #|  t1;
    ),
  )
}

///|
test "Unary plus and minus" {
  let tokens = "SELECT +1, -2 FROM t;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  +1,
      #|  -2
      #|FROM
      #|  t;
    ),
  )
}

///|
test "Unary not expression" {
  let tokens = "SELECT NOT a FROM t;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  NOT a
      #|FROM
      #|  t;
    ),
  )
}

///|
test "Using clause in join" {
  let tokens = "SELECT * FROM t1 JOIN t2 USING (id);"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  *
      #|FROM
      #|  t1 JOIN t2
      #|    USING (id);
    ),
  )
}

///|
test "Multiple statements" {
  let tokens = "SELECT * FROM t1; SELECT * FROM t2;"
  let stmts = parse_sql(tokens) |> pretty_print
  inspect(
    stmts,
    content=(
      #|SELECT
      #|  *
      #|FROM
      #|  t1;
      #|
      #|SELECT
      #|  *
      #|FROM
      #|  t2;
    ),
  )
}

///|
test "String literal as column" {
  let tokens = "SELECT test FROM 't';"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  test
      #|FROM
      #|  t;
    ),
  )
}

///|
test "Limit and offset" {
  let tokens = "SELECT * FROM t LIMIT 10 OFFSET 5;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  *
      #|FROM
      #|  t
      #|LIMIT
      #|  10
      #|OFFSET
      #|  5;
    ),
  )
}

///|
test "Limit without offset" {
  let tokens = "SELECT * FROM t LIMIT N;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  *
      #|FROM
      #|  t
      #|LIMIT
      #|  n;
    ),
  )
}

///|
test "Offset without limit" {
  let tokens = "SELECT * FROM t OFFSET N;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  *
      #|FROM
      #|  t
      #|OFFSET
      #|  n;
    ),
  )
}

///|
test "Duplicate treatment" {
  let tokens = "SELECT COUNT(DISTINCT *) FROM t;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  count(DISTINCT *)
      #|FROM
      #|  t;
    ),
  )
}

///|
test "Substring" {
  let tokens = "SELECT SUBSTRING(col FROM 1 FOR 5) FROM t;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  SUBSTRING(col FROM 1 FOR 5)
      #|FROM
      #|  t;
    ),
  )
}

///|
test "Substring with start only" {
  let tokens = "SELECT SUBSTRING(col FROM 1) FROM t;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  SUBSTRING(col FROM 1)
      #|FROM
      #|  t;
    ),
  )
}

///|
test "Substring another way" {
  let tokens = "SELECT SUBSTRING(col, 1, 5) FROM t;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  SUBSTRING(col FROM 1 FOR 5)
      #|FROM
      #|  t;
    ),
  )
}
