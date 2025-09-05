///|
fn Parser::parse_set_expr(
  self : Parser,
  tokens : ArrayView[Token],
  min_bp : Int,
) -> ParserResult[SetExpr] raise ParserError {
  let mut left_tokens = match tokens {
    [LParen, .. tokens] => {
      let (query, tokens) = self.parse_query(tokens)
      let tokens = self.expect_token(tokens, RParen)
      (SetExpr::Query(query), tokens)
    }
    [Keyword(Select), ..] as tokens => {
      let (select_stmt, tokens) = self.parse_select(tokens)
      (SetExpr::Select(select_stmt), tokens)
    }
    [token, ..] =>
      raise UnexpectedTokenMessageError(
        token, "expected 'SELECT' or '(' to start a set expression",
      )
    [] =>
      raise ParserError::InternalBug("parse_set_expr: unexpected end of tokens")
  }
  for {
    let left = left_tokens.0
    let tokens = left_tokens.1
    // let (op, tokens) = self.parse_next_set_operator(tokens)
    let (op, tokens) = match tokens {
      [Keyword(Union), .. tokens] => (SetOperator::Union, tokens)
      [Keyword(Intersect), .. tokens] => (SetOperator::Intersect, tokens)
      [Keyword(Except), .. tokens] => (SetOperator::Except, tokens)
      tokens => return (left, tokens)
    }
    let next_bp = match op {
      Intersect => 20
      Union => 10
      Except => 10
    }
    if next_bp <= min_bp {
      return (left, tokens)
    }
    let (right, tokens) = self.parse_set_expr(tokens, min_bp)
    left_tokens = (SetExpr::SetOperation(op, left, right), tokens)
  }
}

///|
fn Parser::parse_select(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[SelectStmt] raise ParserError {
  let tokens = self.expect_token(tokens, Keyword(Select))
  let (top, tokens) = self.parse_top(tokens)
  let (distinct, tokens) = match tokens {
    [Keyword(Distinct), .. tokens] => (true, tokens)
    tokens => (false, tokens)
  }
  let (projections, tokens) = self.parse_projections(tokens)
  let (from, tokens) = self.parse_table_refs(tokens)
  let (where_clause, tokens) = match tokens {
    [Keyword(Where), .. tokens] => {
      let (expr, tokens) = self.parse_expr(tokens)
      (Some(expr), tokens)
    }
    _ => (None, tokens)
  }
  let (group_by, tokens) = match tokens {
    [Keyword(Group), Keyword(By), .. tokens] => self.parse_group_by(tokens)
    _ => ([], tokens)
  }
  let (having, tokens) = match tokens {
    [Keyword(Having), .. tokens] => {
      let (expr, tokens) = self.parse_expr(tokens)
      (Some(expr), tokens)
    }
    _ => (None, tokens)
  }
  ({ projections, from, where_clause, group_by, having, distinct, top }, tokens)
}

///|
fn Parser::parse_query(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[QueryStmt] raise ParserError {
  let (with_clause, tokens) = match tokens {
    [Keyword(With), .. tokens] => {
      let (ctes, tokens) = self.parse_cte_list(tokens)
      (Some(ctes), tokens)
    }
    _ => (None, tokens)
  }
  let (body, tokens) = self.parse_set_expr(tokens, 0)
  let (order_by, tokens) = match tokens {
    [Keyword(Order), Keyword(By), .. tokens] => self.parse_order_by(tokens)
    _ => ([], tokens)
  }
  let (limit, tokens) = match tokens {
    [Keyword(Limit), .. tokens] => {
      let (expr, tokens) = self.parse_expr(tokens)
      (Some(expr), tokens)
    }
    _ => (None, tokens)
  }
  let (offset, tokens) = match tokens {
    [Keyword(Offset), .. tokens] => {
      let (expr, tokens) = self.parse_expr(tokens)
      (Some(expr), tokens)
    }
    _ => (None, tokens)
  }
  ({ with_clause, body, order_by, limit, offset }, tokens)
}

///|
fn Parser::parse_aliasing(
  _self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[TableAlias?] raise ParserError {
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
fn Parser::parse_projections(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[Array[Projection]] raise ParserError {
  let projections = []
  if tokens is [Keyword(From), ..] {
    return (projections, tokens)
  }
  loop tokens {
    [Mul, .. tokens] => {
      projections.push(Projection::Wildcard)
      match tokens {
        [Comma, .. tokens] => continue tokens
        _ => break (projections, tokens)
      }
    }
    tokens => {
      let (expr, tokens) = self.parse_expr(tokens)
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
fn Parser::parse_expr(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[Expr] raise ParserError {
  if self.dialect.parse_expr(tokens) is Some(res) {
    return res
  } else {
    self.parse_binary_expr(tokens, 0)
  }
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
fn Parser::parse_binary_expr(
  self : Parser,
  tokens : ArrayView[Token],
  min_bp : Int,
) -> ParserResult[Expr] raise ParserError {
  let mut expr_tokens = self.parse_primary_expr(tokens)
  // Handle postfix operations like array subscripts and field access
  expr_tokens = self.parse_postfix_expr(expr_tokens.0, expr_tokens.1)
  for {
    let expr = expr_tokens.0
    let tokens = expr_tokens.1
    let next_bp = get_next_bp(tokens)
    if next_bp <= min_bp {
      return (expr, tokens)
    }
    expr_tokens = self.parse_infix(tokens, expr, next_bp)
  }
}

///|
fn Parser::parse_infix(
  self : Parser,
  tokens : ArrayView[Token],
  left : Expr,
  min_bp : Int,
) -> ParserResult[Expr] raise ParserError {
  match tokens {
    [token, .. tokens] if try_binary_operator(token) is Some(op) => {
      let (right, tokens) = self.parse_binary_expr(tokens, min_bp)
      let expr = Expr::BinaryOperation(left, op, right)
      (expr, tokens)
    }
    [Keyword(Like), .. tokens] => {
      let (right, tokens) = self.parse_binary_expr(
        tokens,
        Precedence::Like.value(),
      )
      let expr = Expr::Like(positive=true, left, right)
      (expr, tokens)
    }
    [Keyword(ILike), .. tokens] => {
      let (right, tokens) = self.parse_binary_expr(
        tokens,
        Precedence::Like.value(),
      )
      let expr = Expr::ILike(positive=true, left, right)
      (expr, tokens)
    }
    [Keyword(Not), Keyword(Like), .. tokens] => {
      let (right, tokens) = self.parse_binary_expr(
        tokens,
        Precedence::Like.value(),
      )
      let expr = Expr::Like(positive=false, left, right)
      (expr, tokens)
    }
    [Keyword(Not), Keyword(ILike), .. tokens] => {
      let (right, tokens) = self.parse_binary_expr(
        tokens,
        Precedence::Like.value(),
      )
      let expr = Expr::ILike(positive=false, left, right)
      (expr, tokens)
    }
    [Keyword(Between), .. tokens] => self.parse_between_expr(tokens, left, true)
    [Keyword(Not), Keyword(Between), .. tokens] =>
      self.parse_between_expr(tokens, left, false)
    [Keyword(In), .. tokens] => self.parse_in_expr(tokens, left, true)
    [Keyword(Not), Keyword(In), .. tokens] =>
      self.parse_in_expr(tokens, left, false)
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
    Keyword(Div) => Some(BinaryOperator::IntegerDiv) // MySQL DIV operator
    // PostgreSQL JSON operators
    JsonExtract => Some(BinaryOperator::JsonExtract)
    JsonExtractText => Some(BinaryOperator::JsonExtractText)
    JsonExtractPath => Some(BinaryOperator::JsonExtractPath)
    JsonExtractPathText => Some(BinaryOperator::JsonExtractPathText)
    JsonContains => Some(BinaryOperator::JsonContains)
    JsonContainedIn => Some(BinaryOperator::JsonContainedIn)
    _ => None
  }
}

///|
fn Parser::parse_primary_expr(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[Expr] raise ParserError {
  match tokens {
    [Minus as op, .. tokens] | [Plus as op, .. tokens] => {
      let (expr, tokens) = self.parse_binary_expr(
        tokens,
        Precedence::MulDivMod.value(),
      )
      let op = match op {
        Minus => UnaryOperator::Minus
        Plus => UnaryOperator::Plus
        _ =>
          raise ParserError::InternalBug(
            "parse_primary_expr: unexpected operator",
          )
      }
      (UnaryOperation(op, expr), tokens)
    }
    [PlaceHolder, .. tokens] => (PlaceHolder, tokens)
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
    [Keyword(Date), .. tokens] => self.parse_date_expr(tokens)
    [Keyword(Interval), .. tokens] => self.parse_interval_expr(tokens)
    [Keyword(Extract), .. tokens] => self.parse_extract_expr(tokens)
    [Keyword(Substring), .. tokens] => self.parse_substring_expr(tokens)
    [Keyword(Array), LBracket, .. tokens] if self.dialect.supports_array_syntax() =>
      self.parse_array_expr([LBracket, ..tokens], true)
    [LBracket, .. tokens] if self.dialect.supports_array_syntax() =>
      self.parse_array_expr([LBracket, ..tokens], false)
    [Identifier(name), LParen, .. tokens] => {
      let args = []
      let (dup, tokens) = match tokens {
        [Keyword(Distinct), .. tokens] =>
          (Some(DuplicateTreatment::Distinct), tokens)
        [Keyword(All), .. tokens] => (Some(DuplicateTreatment::All), tokens)
        tokens => (None, tokens)
      }
      let tokens = loop tokens {
        [RParen, .. tokens] => break tokens
        tokens => {
          let (arg, tokens) = self.parse_expr(tokens)
          args.push(arg)
          match tokens {
            [Comma, .. tokens] => continue tokens
            [RParen, .. tokens] => break tokens
            _ =>
              raise UnexpectedTokenMessageError(
                tokens[0],
                "expected ',' or ')'",
              )
          }
        }
      }
      // Parse optional FILTER clause
      let (filter, tokens) = if self.dialect.supports_filter_during_aggregation() {
        match tokens {
          [Keyword(Filter), LParen, Keyword(Where), .. tokens] => {
            let (filter_expr, tokens) = self.parse_expr(tokens)
            let tokens = self.expect_token(tokens, RParen)
            (Some(filter_expr), tokens)
          }
          _ => (None, tokens)
        }
      } else {
        (None, tokens)
      }
      // Check for OVER clause to create window function
      match tokens {
        [Keyword(Over), LParen, .. tokens] => {
          let (window_spec, tokens) = self.parse_window_spec(tokens)
          let tokens = self.expect_token(tokens, RParen)
          (WindowFunction(name, dup, args, window_spec), tokens)
        }
        _ => (FunctionCall(name, dup, args, filter), tokens)
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
    [Identifier(name), .. tokens] =>
      // Check if this is a BigQuery named parameter (@param_name)
      if name.strip_prefix("@") is Some(_) &&
        self.dialect.supports_named_parameters() {
        let param_name = name.substring(start=1) // Remove the @ prefix
        (NamedParameter(param_name), tokens)
      } else {
        (Identifier(name), tokens)
      }
    [Keyword(Exists), LParen, .. tokens] => {
      let (sub_query, tokens) = self.parse_query(tokens)
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
      let (sub_query, tokens) = self.parse_query(tokens)
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
      let (expr, tokens) = self.parse_binary_expr(
        tokens,
        Precedence::UnaryNot.value(),
      )
      (Expr::UnaryOperation(UnaryOperator::Not, expr), tokens)
    }
    [Keyword(Case), .. tokens] => self.parse_case_expr(tokens)
    [Token::LParen, .. tokens] => {
      let (expr, tokens) = try self.parse_query(tokens) catch {
        _ => self.parse_expr(tokens)
      } noraise {
        (stmt, tokens) => (Expr::SubQuery(stmt), tokens)
      }
      let tokens = self.expect_token(tokens, RParen)
      (expr, tokens)
    }
    [Token::Mul, .. tokens] => (Expr::Wildcard, tokens)
    // Handle keywords that can also be used as identifiers
    [Keyword(Status), .. tokens] => (Identifier("status"), tokens)
    [token, .. _tokens] =>
      raise UnimplementedError("parse_primary_expr: \{token}")
    [] =>
      raise ParserError::InternalBug(
        "parse_primary_expr: unexpected end of tokens",
      )
  }
}

///|
fn Parser::parse_postfix_expr(
  self : Parser,
  expr : Expr,
  tokens : ArrayView[Token],
) -> ParserResult[Expr] raise ParserError {
  let mut current_expr = expr
  let remaining_tokens = tokens

  // Parse multiple postfix operations in sequence  
  loop remaining_tokens {
    // Array/object indexing: expr[index] or expr[start:end]
    [LBracket, .. rest_tokens] => {
      let (subscript, next_tokens) = self.parse_subscript(rest_tokens)
      let access_chain = [AccessExpr::Subscript(subscript)]
      current_expr = CompoundFieldAccess(current_expr, access_chain)
      continue next_tokens
    }
    // Field access: expr.field
    [Period, Identifier(field_name), .. rest_tokens] => {
      let access_chain = [AccessExpr::Dot(Identifier(field_name))]
      current_expr = CompoundFieldAccess(current_expr, access_chain)
      continue rest_tokens
    }
    // No more postfix operations
    final_tokens => break (current_expr, final_tokens)
  }
}

///|
fn Parser::parse_subscript(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[Subscript] raise ParserError {
  // tokens start right after the '['
  match tokens {
    // Handle slice notation: [start:end] or [start:end:stride] or [:end] or [start:]
    tokens =>
      match tokens {
        // Handle [:...] format (colon at the beginning)
        [Colon, .. tokens] => {
          let (second_expr, tokens) = match tokens {
            [Colon, .. tokens] => (Option::None, tokens) // [::stride] format  
            [RBracket, .. tokens] => (Option::None, [RBracket, ..tokens]) // [:] format
            tokens => {
              let (expr, tokens) = self.parse_expr(tokens)
              (Option::Some(expr), tokens)
            }
          }
          let (third_expr, tokens) = match tokens {
            [Colon, .. tokens] => {
              // [start:end:stride] format
              let (expr, tokens) = self.parse_expr(tokens)
              (Option::Some(expr), tokens)
            }
            tokens => (Option::None, tokens)
          }
          let tokens = self.expect_token(tokens, RBracket)
          (Subscript::Slice(Option::None, second_expr, third_expr), tokens)
        }
        // Handle [expr...] format (expression at the beginning)
        tokens => {
          let (first_expr, tokens) = self.parse_expr(tokens)
          match tokens {
            // Simple index: [expr]
            [RBracket, .. tokens] => (Subscript::Index(first_expr), tokens)
            // Slice notation: [expr:...]
            [Colon, .. tokens] => {
              let (second_expr, tokens) = match tokens {
                [Colon, .. tokens] => (Option::None, tokens) // [start::stride] format
                [RBracket, .. tokens] => (Option::None, [RBracket, ..tokens]) // [start:] format
                tokens => {
                  let (expr, tokens) = self.parse_expr(tokens)
                  (Option::Some(expr), tokens)
                }
              }
              let (third_expr, tokens) = match tokens {
                [Colon, .. tokens] => {
                  // [start:end:stride] format
                  let (expr, tokens) = self.parse_expr(tokens)
                  (Option::Some(expr), tokens)
                }
                tokens => (Option::None, tokens)
              }
              let tokens = self.expect_token(tokens, RBracket)
              (
                Subscript::Slice(
                  Option::Some(first_expr),
                  second_expr,
                  third_expr,
                ),
                tokens,
              )
            }
            [token, .. _tokens] =>
              raise UnexpectedTokenMessageError(token, "expected ':' or ']'")
            [] =>
              raise ParserError::InternalBug(
                "parse_subscript: unexpected end of tokens",
              )
          }
        }
      }
  }
}

///|
fn Parser::parse_table_refs(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[Array[TableRef]] raise ParserError {
  let tokens = self.expect_token(tokens, Keyword(From))
  let table_refs = []
  loop tokens {
    tokens => {
      let (table_ref, tokens) = self.parse_table_ref(tokens)
      table_refs.push(table_ref)
      match tokens {
        [Comma, .. tokens] => continue tokens
        tokens => break (table_refs, tokens)
      }
    }
  }
}

///|
fn Parser::parse_table_ref(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[TableRef] raise ParserError {
  let (factor, tokens) = self.parse_table_factor(tokens)
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
      let (table_ref, tokens) = self.parse_table_ref(tokens)
      match tokens {
        [Keyword(On), .. tokens] => {
          let (constraint, tokens) = self.parse_expr(tokens)
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
      let (table_ref, tokens) = self.parse_table_ref(tokens)
      joins.push({ join_operator: JoinOperator::Cross, table_ref })
      continue tokens
    }
    tokens => break tokens
  }
  ({ factor, joins }, tokens)
}

///|
fn Parser::parse_table_factor(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[TableFactor] raise ParserError {
  match tokens {
    [Identifier(_) | StringLiteral(_), ..] as tokens => {
      let (object_name, tokens) = self.parse_object_name(tokens)
      let (optional_alias, tokens) = self.parse_aliasing(tokens)
      (TableFactor::Column(object_name, optional_alias), tokens)
    }
    [Token::LParen, .. tokens] => {
      let (sub_query, tokens) = self.parse_query(tokens)
      let tokens = self.expect_token(tokens, RParen)
      let (optional_alias, tokens) = self.parse_aliasing(tokens)
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
fn Parser::parse_group_by(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[Array[Expr]] raise ParserError {
  let group_by = []
  loop tokens {
    tokens => {
      let (expr, tokens) = self.parse_expr(tokens)
      group_by.push(expr)
      match tokens {
        [Comma, .. tokens] => continue tokens
        _ => break (group_by, tokens)
      }
    }
  }
}

///|
fn Parser::parse_order_by(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[Array[OrderByExpr]] raise ParserError {
  let order_by = []
  loop tokens {
    tokens => {
      let (order_by_expr, tokens) = self.parse_order_by_expr(tokens)
      order_by.push(order_by_expr)
      match tokens {
        [Comma, .. tokens] => continue tokens
        _ => break (order_by, tokens)
      }
    }
  }
}

///|
fn Parser::parse_order_by_expr(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[OrderByExpr] raise ParserError {
  let (expr, tokens) = self.parse_expr(tokens)
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
fn Parser::parse_date_expr(
  _self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[Expr] raise ParserError {
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
fn Parser::parse_interval_expr(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[Expr] raise ParserError {
  match tokens {
    [StringLiteral(s), .. tokens] => {
      let (qualifier, tokens) = self.parse_interval_qualifier(tokens)
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
fn Parser::parse_extract_expr(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[Expr] raise ParserError {
  match tokens {
    [LParen, .. tokens] => {
      let (field, tokens) = self.parse_primary_datetime_field(tokens)
      let tokens = self.expect_token(tokens, Keyword(From))
      let (expr, tokens) = self.parse_expr(tokens)
      let tokens = self.expect_token(tokens, RParen)
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
fn Parser::parse_case_expr(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[Expr] raise ParserError {
  let when_then_clauses = []
  let mut else_expr : Expr? = None
  let (operand, tokens) : (Expr?, _) = match tokens {
    [Keyword(When), ..] => (None, tokens)
    tokens => {
      let (expr, tokens) = self.parse_expr(tokens)
      (Some(expr), tokens)
    }
  }
  loop tokens {
    [Keyword(When), .. tokens] => {
      let (condition, tokens) = self.parse_expr(tokens)
      let tokens = self.expect_token(tokens, Keyword(Then))
      let (result, tokens) = self.parse_expr(tokens)
      when_then_clauses.push((condition, result))
      continue tokens
    }
    [Keyword(Else), .. tokens] => {
      if else_expr is Some(_e) {
        raise MultipleElseInCaseExprError
      }
      let (expr, tokens) = self.parse_expr(tokens)
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
fn Parser::parse_interval_qualifier(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[IntervalQualifier] raise ParserError {
  let (field1, tokens) = self.parse_primary_datetime_field(tokens)
  match tokens {
    [Keyword(To), .. tokens] => {
      let field2 = self.parse_primary_datetime_field(tokens)
      match field2 {
        (field2, tokens) => (IntervalQualifier::Range(field1, field2), tokens)
      }
    }
    _ => (IntervalQualifier::Single(field1), tokens)
  }
}

///|
fn Parser::parse_primary_datetime_field(
  _self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[PrimaryDatetimeField] raise ParserError {
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
fn Parser::parse_between_expr(
  self : Parser,
  tokens : ArrayView[Token],
  left : Expr,
  positive : Bool,
) -> ParserResult[Expr] raise ParserError {
  let (low, tokens) = self.parse_binary_expr(
    tokens,
    Precedence::Between.value(),
  )
  match tokens {
    [Keyword(And), .. tokens] => {
      let (hi, tokens) = self.parse_binary_expr(
        tokens,
        Precedence::Between.value(),
      )
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
fn Parser::parse_in_expr(
  self : Parser,
  tokens : ArrayView[Token],
  left : Expr,
  positive : Bool,
) -> ParserResult[Expr] raise ParserError {
  let tokens = self.expect_token(tokens, LParen)
  try self.parse_query(tokens) catch {
    _ => {
      let items = []
      let tokens = loop tokens {
        tokens => {
          let (item, tokens) = self.parse_expr(tokens)
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
fn Parser::parse_substring_expr(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[Expr] raise ParserError {
  let tokens = self.expect_token(tokens, LParen)
  let (expr, tokens) = self.parse_expr(tokens)
  let (start, len, tokens) = match tokens {
    [Keyword(From), .. tokens] => {
      let (start_expr, tokens) = self.parse_expr(tokens)
      let (len_expr, tokens) = match tokens {
        [Keyword(For), .. tokens] => {
          let (len_expr, tokens) = self.parse_expr(tokens)
          (Some(len_expr), tokens)
        }
        _ => (None, tokens)
      }
      (Some(start_expr), len_expr, tokens)
    }
    [Comma, .. tokens] => {
      let (start_expr, tokens) = self.parse_expr(tokens)
      let (len_expr, tokens) = match tokens {
        [Comma, .. tokens] => {
          let (len_expr, tokens) = self.parse_expr(tokens)
          (Some(len_expr), tokens)
        }
        _ => (None, tokens)
      }
      (Some(start_expr), len_expr, tokens)
    }
    tokens => (None, None, tokens)
  }
  let tokens = self.expect_token(tokens, RParen)
  (Substring(expr, start, len), tokens)
}

///|
fn Parser::parse_array_expr(
  self : Parser,
  tokens : ArrayView[Token],
  named : Bool,
) -> ParserResult[Expr] raise ParserError {
  let tokens = self.expect_token(tokens, LBracket)
  let elements = []
  let tokens = loop tokens {
    [RBracket, .. tokens] => break tokens
    tokens => {
      let (expr, tokens) = self.parse_expr(tokens)
      elements.push(expr)
      match tokens {
        [Comma, .. tokens] => continue tokens
        [RBracket, .. tokens] => break tokens
        [token, .. _tokens] =>
          raise UnexpectedTokenMessageError(token, "expected ',' or ']'")
        [] =>
          raise ParserError::InternalBug(
            "parse_array_expr: unexpected end of tokens",
          )
      }
    }
  }
  (Array(ArrayExpr::{ elem: elements, named }), tokens)
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
  let stmt = parse_sql(tokens, dialect=Postgres::{  })[0] |> pretty_print
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
  let stmt = parse_sql(dialect=Postgres::{  }, tokens)[0] |> pretty_print
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

///|
fn Parser::parse_object_name(
  _self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[ObjectName] raise ParserError {
  let parts = []
  loop tokens {
    [Identifier(part) | StringLiteral(part), Period, .. tokens] => {
      parts.push(part)
      continue tokens
    }
    [Identifier(part) | StringLiteral(part), .. tokens] => {
      parts.push(part)
      break ({ parts, }, tokens)
    }
    [token, .. _tokens] =>
      raise UnexpectedTokenMessageError(
        token, "expected another identifier after '.'",
      )
    [] =>
      raise ParserError::InternalBug(
        "parse_object_name: unexpected end of tokens",
      )
  }
}

///|
test {
  let tokens = "SELECT * FROM t1 UNION (SELECT * FROM t2 UNION SELECT * FROM t3) ORDER BY col1;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  *
      #|FROM
      #|  t1
      #|UNION
      #|(
      #|  SELECT
      #|    *
      #|  FROM
      #|    t2
      #|  UNION
      #|  SELECT
      #|    *
      #|  FROM
      #|    t3
      #|)
      #|ORDER BY
      #|  col1;
    ),
  )
}

///|
test "Non projections" {
  let tokens = "SELECT FROM t1;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  *
      #|FROM
      #|  t1;
    ),
  )
}

///|
fn Parser::parse_top(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[Top?] raise ParserError {
  match tokens {
    [Keyword(Top), Number(n), .. tokens] => {
      let n = @strconv.parse_int(n) catch {
        StrConvError(e) => raise ParserError::InternalBug("parse_top: \{e}")
      }
      (Some(Constant(n)), tokens)
    }
    [Keyword(Top), LParen, .. tokens] => {
      let (expr, tokens) = self.parse_expr(tokens)
      let tokens = self.expect_token(tokens, RParen)
      (Some(Expr(expr)), tokens)
    }
    _ => (None, tokens)
  }
}

///|
test "Top 10" {
  let tokens = "SELECT TOP 10 * FROM t;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT TOP 10
      #|  *
      #|FROM
      #|  t;
    ),
  )
}

///|
fn Parser::parse_insert_statement(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[InsertStmt] raise ParserError {
  let tokens = self.expect_token(tokens, Keyword(Insert))

  // Parse optional conflict resolution (OR REPLACE, OR IGNORE, etc.)
  let (or_conflict, tokens) = match tokens {
    [Keyword(Or), Keyword(Replace), .. tokens] =>
      (Some(SqliteOnConflict::Replace), tokens)
    [Keyword(Or), Keyword(Rollback), .. tokens] =>
      (Some(SqliteOnConflict::Rollback), tokens)
    [Keyword(Or), Keyword(Abort), .. tokens] =>
      (Some(SqliteOnConflict::Abort), tokens)
    [Keyword(Or), Keyword(Fail), .. tokens] =>
      (Some(SqliteOnConflict::Fail), tokens)
    [Keyword(Or), Keyword(Ignore), .. tokens] =>
      (Some(SqliteOnConflict::Ignore), tokens)
    _ => (None, tokens)
  }
  let tokens = self.expect_token(tokens, Keyword(Into))
  let (table_name, tokens) = self.parse_object_name(tokens)

  // Parse optional column list: (col1, col2, ...)
  let (columns, tokens) = match tokens {
    [LParen, .. tokens] => {
      let columns = []
      loop tokens {
        [Identifier(col), Comma, .. tokens] => {
          columns.push(col)
          continue tokens
        }
        [Identifier(col), RParen, .. tokens] => {
          columns.push(col)
          break (columns, tokens)
        }
        // Handle keywords as column names
        [Keyword(keyword), Comma, .. tokens] => {
          columns.push(keyword.to_string().to_lower())
          continue tokens
        }
        [Keyword(keyword), RParen, .. tokens] => {
          columns.push(keyword.to_string().to_lower())
          break (columns, tokens)
        }
        [token, .. _tokens] =>
          raise UnexpectedTokenMessageError(
            token, "expected column name in INSERT column list",
          )
        [] =>
          raise InternalBug("parse_insert_statement: unexpected end of tokens")
      }
    }
    _ => ([], tokens)
  }

  // Parse INSERT source (VALUES or SELECT)
  let (source, tokens) = match tokens {
    [Keyword(Values), .. tokens] => {
      let rows = []
      loop tokens {
        [LParen, .. tokens] => {
          let row = []
          let tokens = loop tokens {
            [RParen, .. tokens] => break tokens
            tokens => {
              let (expr, tokens) = self.parse_expr(tokens)
              row.push(expr)
              match tokens {
                [Comma, .. tokens] => continue tokens
                [RParen, .. tokens] => break tokens
                [token, .. _tokens] =>
                  raise UnexpectedTokenMessageError(
                    token, "expected ',' or ')'",
                  )
                [] =>
                  raise InternalBug(
                    "parse_insert_statement: unexpected end of tokens",
                  )
              }
            }
          }
          rows.push(row)
          match tokens {
            [Comma, .. tokens] => continue tokens
            _ => break (InsertSource::Values(rows), tokens)
          }
        }
        [token, .. _tokens] =>
          raise UnexpectedTokenMessageError(token, "expected '(' after VALUES")
        [] =>
          raise InternalBug("parse_insert_statement: unexpected end of tokens")
      }
    }
    [Keyword(Select), .. _tokens] => {
      let (query, tokens) = self.parse_query(tokens)
      (InsertSource::Query(query), tokens)
    }
    [token, .. _tokens] =>
      raise UnexpectedTokenMessageError(token, "expected VALUES or SELECT")
    [] => raise InternalBug("parse_insert_statement: unexpected end of tokens")
  }

  // Parse optional ON DUPLICATE KEY UPDATE clause
  let (on_insert, tokens) = match tokens {
    [Keyword(On), Keyword(Duplicate), Keyword(Key), Keyword(Update), .. tokens] => {
      let (assignments, tokens) = self.parse_duplicate_key_assignments(tokens)
      (Some(OnInsert::DuplicateKeyUpdate(assignments)), tokens)
    }
    _ => (None, tokens)
  }
  ({ table_name, columns, source, or: or_conflict, on: on_insert }, tokens)
}

///|
test "Insert with values - simple" {
  let tokens = "INSERT INTO test_table VALUES (1, 2, 'test');"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|INSERT INTO test_table VALUES (1, 2, 'test');
    ),
  )
}

///|
test "Insert with columns and values" {
  let tokens = "INSERT INTO test_table (id, value, name) VALUES (1, 2, 'test');"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|INSERT INTO test_table (id, value, name) VALUES (1, 2, 'test');
    ),
  )
}

///|
test "Insert with SELECT" {
  let tokens = "INSERT INTO test_table SELECT * FROM students;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|INSERT INTO test_table SELECT
      #|  *
      #|FROM
      #|  students;
    ),
  )
}

///|
test "Insert with schema" {
  let tokens = "INSERT INTO some_schema.test_table SELECT * FROM another_schema.students;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|INSERT INTO some_schema.test_table SELECT
      #|  *
      #|FROM
      #|  another_schema.students;
    ),
  )
}

///|
fn Parser::parse_delete_statement(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[DeleteStmt] raise ParserError {
  let tokens = self.expect_token(tokens, Keyword(Delete))
  let tokens = self.expect_token(tokens, Keyword(From))
  let (table_name, tokens) = self.parse_object_name(tokens)

  // Parse optional WHERE clause
  let (where_clause, tokens) = match tokens {
    [Keyword(Where), .. tokens] => {
      let (expr, tokens) = self.parse_expr(tokens)
      (Some(expr), tokens)
    }
    _ => (None, tokens)
  }
  ({ table_name, where_clause }, tokens)
}

///|
test "Delete with WHERE" {
  let tokens = "DELETE FROM students WHERE grade > 3.0;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|DELETE FROM students
      #|WHERE grade > 3;
    ),
  )
}

///|
test "Delete without WHERE" {
  let tokens = "DELETE FROM students;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|DELETE FROM students;
    ),
  )
}

///|
fn Parser::parse_update_statement(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[UpdateStmt] raise ParserError {
  let tokens = self.expect_token(tokens, Keyword(Update))
  let (table_name, tokens) = self.parse_object_name(tokens)
  let tokens = self.expect_token(tokens, Keyword(Set))

  // Parse assignments: col1 = expr1, col2 = expr2, ...
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
      raise UnexpectedTokenMessageError(token, "expected column assignment")
    [] => raise InternalBug("parse_update_statement: unexpected end of tokens")
  }

  // Parse optional WHERE clause
  let (where_clause, tokens) = match tokens {
    [Keyword(Where), .. tokens] => {
      let (expr, tokens) = self.parse_expr(tokens)
      (Some(expr), tokens)
    }
    _ => (None, tokens)
  }
  ({ table_name, assignments, where_clause }, tokens)
}

///|
test "Update with single assignment and WHERE" {
  let tokens = "UPDATE students SET grade = 1.3 WHERE name = 'Max Mustermann';"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|UPDATE students
      #|SET grade = 1.3
      #|WHERE name = 'Max Mustermann';
    ),
  )
}

///|
test "Update with multiple assignments and WHERE" {
  let tokens = "UPDATE students SET grade = 1.3, name='Felix Fürstenberg' WHERE name = 'Max Mustermann';"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|UPDATE students
      #|SET grade = 1.3, name = 'Felix Fürstenberg'
      #|WHERE name = 'Max Mustermann';
    ),
  )
}

///|
test "Update without WHERE" {
  let tokens = "UPDATE students SET grade = 1.0;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|UPDATE students
      #|SET grade = 1;
    ),
  )
}

///|
fn Parser::parse_truncate_statement(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[TruncateStmt] raise ParserError {
  let tokens = self.expect_token(tokens, Keyword(Truncate))
  let (table_name, tokens) = self.parse_object_name(tokens)
  ({ table_name, }, tokens)
}

///|
fn Parser::parse_cte_list(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[Array[Cte]] raise ParserError {
  let ctes = []
  let tokens = loop tokens {
    tokens => {
      let (cte, tokens) = self.parse_cte(tokens)
      ctes.push(cte)
      match tokens {
        [Comma, .. tokens] => continue tokens
        tokens => break tokens
      }
    }
  }
  (ctes, tokens)
}

///|
fn Parser::parse_cte(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[Cte] raise ParserError {
  // Parse CTE name
  let (cte_name, tokens) = match tokens {
    [Identifier(name), .. tokens] => (name, tokens)
    [token, .. _tokens] =>
      raise UnexpectedTokenMessageError(token, "expected CTE name")
    [] => raise ParserError::InternalBug("parse_cte: unexpected end of tokens")
  }

  // Parse optional column list: cte_name(col1, col2, ...)
  let (columns, tokens) = match tokens {
    [LParen, .. tokens] => {
      let cols = []
      let tokens = loop tokens {
        [RParen, .. tokens] => break tokens
        [Identifier(col), .. tokens] => {
          cols.push(col)
          match tokens {
            [Comma, .. tokens] => continue tokens
            [RParen, .. tokens] => break tokens
            [token, .. _tokens] =>
              raise UnexpectedTokenMessageError(token, "expected ',' or ')'")
            [] =>
              raise ParserError::InternalBug(
                "parse_cte: unexpected end of tokens in column list",
              )
          }
        }
        [token, .. _tokens] =>
          raise UnexpectedTokenMessageError(token, "expected column name")
        [] =>
          raise ParserError::InternalBug(
            "parse_cte: unexpected end of tokens in column list",
          )
      }
      (Some(cols), tokens)
    }
    _ => (None, tokens)
  }

  // Parse AS keyword
  let tokens = self.expect_token(tokens, Keyword(As))

  // Parse parenthesized query
  let tokens = self.expect_token(tokens, LParen)
  let (query, tokens) = self.parse_query(tokens)
  let tokens = self.expect_token(tokens, RParen)
  ({ name: cte_name, query, columns }, tokens)
}

///|
/// Parse window specification: [PARTITION BY ...] [ORDER BY ...] [frame_clause]
fn Parser::parse_window_spec(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[WindowSpec] raise ParserError {
  // Parse optional PARTITION BY clause
  let (partition_by, tokens) = match tokens {
    [Keyword(Partition), Keyword(By), .. tokens] => {
      let exprs = []
      let tokens = loop tokens {
        tokens => {
          let (expr, tokens) = self.parse_expr(tokens)
          exprs.push(expr)
          match tokens {
            [Comma, .. tokens] => continue tokens
            _ => break tokens
          }
        }
      }
      (exprs, tokens)
    }
    _ => ([], tokens)
  }

  // Parse optional ORDER BY clause
  let (order_by, tokens) = match tokens {
    [Keyword(Order), Keyword(By), .. tokens] => {
      let order_exprs = []
      let tokens = loop tokens {
        tokens => {
          let (order_expr, tokens) = self.parse_order_by_expr(tokens)
          order_exprs.push(order_expr)
          match tokens {
            [Comma, .. tokens] => continue tokens
            _ => break tokens
          }
        }
      }
      (order_exprs, tokens)
    }
    _ => ([], tokens)
  }

  // Parse optional frame clause
  let (frame_clause, tokens) = self.parse_window_frame_clause(tokens)
  ({ partition_by, order_by, frame_clause }, tokens)
}

///|
/// Parse window frame clause: ROWS/RANGE [BETWEEN ... AND ...] or ROWS/RANGE ...
fn Parser::parse_window_frame_clause(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[WindowFrameClause?] raise ParserError {
  match tokens {
    [Keyword(Rows), .. tokens] =>
      self.parse_frame_bounds(WindowFrameUnits::Rows, tokens)
    [Keyword(Range), .. tokens] =>
      self.parse_frame_bounds(WindowFrameUnits::Range, tokens)
    _ => (None, tokens)
  }
}

///|
/// Parse frame bounds: [BETWEEN ... AND ...] or single bound
fn Parser::parse_frame_bounds(
  self : Parser,
  frame_units : WindowFrameUnits,
  tokens : ArrayView[Token],
) -> ParserResult[WindowFrameClause?] raise ParserError {
  match tokens {
    [Keyword(Unbounded), Keyword(Preceding), .. tokens] => {
      let frame_start = WindowFrameBound::UnboundedPreceding
      (Some({ frame_units, frame_start, frame_end: None }), tokens)
    }
    [Keyword(Current), Keyword(Row), .. tokens] => {
      let frame_start = WindowFrameBound::CurrentRow
      (Some({ frame_units, frame_start, frame_end: None }), tokens)
    }
    [Keyword(Between), .. tokens] => {
      // Parse start bound
      let (frame_start, tokens) = self.parse_frame_bound(tokens)
      let tokens = self.expect_token(tokens, Keyword(And))
      // Parse end bound
      let (frame_end, tokens) = self.parse_frame_bound(tokens)
      (Some({ frame_units, frame_start, frame_end: Some(frame_end) }), tokens)
    }
    _ => {
      // Try to parse a single expression followed by PRECEDING/FOLLOWING
      let (expr, tokens) = self.parse_expr(tokens) catch {
        _ => return (None, tokens)
      }
      match tokens {
        [Keyword(Preceding), .. tokens] =>
          (
            Some({
              frame_units,
              frame_start: WindowFrameBound::Preceding(expr),
              frame_end: None,
            }),
            tokens,
          )
        [Keyword(Following), .. tokens] =>
          (
            Some({
              frame_units,
              frame_start: WindowFrameBound::Following(expr),
              frame_end: None,
            }),
            tokens,
          )
        _ => (None, tokens) // Not a frame clause, backtrack
      }
    }
  }
}

///|
/// Parse individual frame bound
fn Parser::parse_frame_bound(
  self : Parser,
  tokens : ArrayView[Token],
) -> ParserResult[WindowFrameBound] raise ParserError {
  match tokens {
    [Keyword(Unbounded), Keyword(Preceding), .. tokens] =>
      (WindowFrameBound::UnboundedPreceding, tokens)
    [Keyword(Unbounded), Keyword(Following), .. tokens] =>
      (WindowFrameBound::UnboundedFollowing, tokens)
    [Keyword(Current), Keyword(Row), .. tokens] =>
      (WindowFrameBound::CurrentRow, tokens)
    _ => {
      let (expr, tokens) = self.parse_expr(tokens)
      match tokens {
        [Keyword(Preceding), .. tokens] =>
          (WindowFrameBound::Preceding(expr), tokens)
        [Keyword(Following), .. tokens] =>
          (WindowFrameBound::Following(expr), tokens)
        [token, .. _tokens] =>
          raise UnexpectedTokenMessageError(
            token, "expected PRECEDING or FOLLOWING",
          )
        [] =>
          raise ParserError::InternalBug(
            "parse_frame_bound: unexpected end of tokens",
          )
      }
    }
  }
}

///|
test "Truncate table" {
  let tokens = "TRUNCATE students;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|TRUNCATE students;
    ),
  )
}

///|
// WITH clause (Common Table Expression) tests

test "Simple CTE with WITH clause" {
  let tokens = "WITH sales AS (SELECT * FROM orders) SELECT * FROM sales;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|WITH sales AS (
      #|  SELECT
      #|    *
      #|  FROM
      #|    orders
      #|)
      #|SELECT
      #|  *
      #|FROM
      #|  sales;
    ),
  )
}

///|
test "CTE with column specification" {
  let tokens = "WITH sales(id, total) AS (SELECT order_id, amount FROM orders) SELECT * FROM sales;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|WITH sales(id, total) AS (
      #|  SELECT
      #|    order_id,
      #|    amount
      #|  FROM
      #|    orders
      #|)
      #|SELECT
      #|  *
      #|FROM
      #|  sales;
    ),
  )
}

///|
test "Multiple CTEs" {
  let tokens = "WITH sales AS (SELECT * FROM orders), customers AS (SELECT * FROM users) SELECT * FROM sales JOIN customers ON sales.user_id = customers.id;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|WITH sales AS (
      #|  SELECT
      #|    *
      #|  FROM
      #|    orders
      #|), 
      #|customers AS (
      #|  SELECT
      #|    *
      #|  FROM
      #|    users
      #|)
      #|SELECT
      #|  *
      #|FROM
      #|  sales JOIN customers
      #|    ON sales.user_id = customers.id;
    ),
  )
}

///|
test "CTE with ORDER BY and LIMIT" {
  let tokens = "WITH top_sales AS (SELECT * FROM orders ORDER BY amount DESC LIMIT 10) SELECT * FROM top_sales;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|WITH top_sales AS (
      #|  SELECT
      #|    *
      #|  FROM
      #|    orders
      #|  ORDER BY
      #|    amount DESC
      #|  LIMIT
      #|    10
      #|)
      #|SELECT
      #|  *
      #|FROM
      #|  top_sales;
    ),
  )
}

///|
test "Nested CTE (CTE referencing another CTE)" {
  let tokens = "WITH sales AS (SELECT * FROM orders), big_sales AS (SELECT * FROM sales WHERE amount > 1000) SELECT * FROM big_sales;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|WITH sales AS (
      #|  SELECT
      #|    *
      #|  FROM
      #|    orders
      #|), 
      #|big_sales AS (
      #|  SELECT
      #|    *
      #|  FROM
      #|    sales
      #|  WHERE
      #|    amount > 1000
      #|)
      #|SELECT
      #|  *
      #|FROM
      #|  big_sales;
    ),
  )
}

///|
test "CTE with aggregation" {
  let tokens = "WITH monthly_sales AS (SELECT date_month, SUM(amount) as total FROM orders GROUP BY date_month) SELECT * FROM monthly_sales;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|WITH monthly_sales AS (
      #|  SELECT
      #|    date_month,
      #|    sum(amount) AS total
      #|  FROM
      #|    orders
      #|  GROUP BY
      #|    date_month
      #|)
      #|SELECT
      #|  *
      #|FROM
      #|  monthly_sales;
    ),
  )
}

///|
/// Window Functions Tests
test "Simple window function with empty OVER clause" {
  let tokens = "SELECT rank() OVER () FROM test;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  rank() OVER ()
      #|FROM
      #|  test;
    ),
  )
}

///|
test "Window function with ORDER BY" {
  let tokens = "SELECT rank() OVER (ORDER BY salary DESC) FROM employees;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  rank() OVER (ORDER BY salary DESC)
      #|FROM
      #|  employees;
    ),
  )
}

///|
test "Window function with PARTITION BY" {
  let tokens = "SELECT count(*) OVER (PARTITION BY department) FROM employees;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  count(*) OVER (PARTITION BY department)
      #|FROM
      #|  employees;
    ),
  )
}

///|
test "Window function with PARTITION BY and ORDER BY" {
  let tokens = "SELECT row_number() OVER (PARTITION BY department ORDER BY salary DESC) FROM employees;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  row_number() OVER (PARTITION BY department ORDER BY salary DESC)
      #|FROM
      #|  employees;
    ),
  )
}

///|
test "Window function with ROWS frame - UNBOUNDED PRECEDING" {
  let tokens = "SELECT sum(salary) OVER (ORDER BY hire_date ROWS UNBOUNDED PRECEDING) FROM employees;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  sum(salary) OVER (ORDER BY hire_date ROWS UNBOUNDED PRECEDING)
      #|FROM
      #|  employees;
    ),
  )
}

///|
test "Window function with ROWS frame - BETWEEN" {
  let tokens = "SELECT avg(salary) OVER (ORDER BY hire_date ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING) FROM employees;"
  let stmt = parse_sql(tokens)[0] |> pretty_print
  inspect(
    stmt,
    content=(
      #|SELECT
      #|  avg(salary) OVER (ORDER BY hire_date ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING)
      #|FROM
      #|  employees;
    ),
  )
}
