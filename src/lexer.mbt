///|
suberror LexerError {
  UnterminatedString
  UnknownCharacter(Char)
} derive(Show)

///|
pub(all) enum Token {
  Keyword(Keyword)
  Identifier(String)
  Number(String)
  StringLiteral(String)
  Boolean(Bool)
  Comma
  Semicolon
  Eq
  DoubleEq
  Neq
  Lt
  Gt
  LtEq
  GtEq
  Spaceship
  Plus
  Minus
  Mul // Asterisk
  Div
  Mod
  LBracket
  RBracket
  LBrace
  RBrace
  LParen
  RParen
  Period
  PlaceHolder
  Unknown(Char)
  Eof
} derive(Eq, Show)

///|
priv struct Lexer {
  dialect : &Dialect
}

///|
pub fn tokenize(
  dialect~ : &Dialect = MySQL::{  },
  input : String,
) -> Array[Token] raise LexerError {
  let lexer = Lexer::{ dialect, }
  let tokens = []
  loop input[:] {
    [] => break
    input => {
      let (token, input) = lexer.next_token(input)
      tokens.push(token)
      continue input
    }
  }
  tokens
}

///|
fn Lexer::next_token(
  self : Lexer,
  input : @string.View,
) -> (Token, @string.View) raise LexerError {
  match skip_whitespace(input) {
    [',', .. rest] => (Comma, rest)
    ['?', .. rest] => (PlaceHolder, rest)
    [';', .. rest] => (Semicolon, rest)
    ['*', .. rest] => (Mul, rest)
    [.. "==", .. rest] => (DoubleEq, rest)
    ['=', .. rest] => (Eq, rest)
    [.. "<=>", .. rest] => (Spaceship, rest)
    [.. "<>", .. rest] => (Neq, rest)
    [.. "<=", .. rest] => (LtEq, rest)
    ['<', .. rest] => (Lt, rest)
    [.. ">=", .. rest] => (GtEq, rest)
    ['>', .. rest] => (Gt, rest)
    ['+', .. rest] => (Plus, rest)
    [.. "--", .. rest] => {
      let rest = skip_line_comment(rest)
      self.next_token(rest)
    }
    ['-', .. rest] => (Minus, rest)
    ['/', .. rest] => (Div, rest)
    ['%', .. rest] => (Mod, rest)
    ['(', .. rest] => (LParen, rest)
    [')', .. rest] => (RParen, rest)
    ['[', .. rest] => (LBracket, rest)
    [']', .. rest] => (RBracket, rest)
    ['{', .. rest] => (LBrace, rest)
    ['}', .. rest] => (RBrace, rest)
    ['\'', .. rest] => self.read_single_quoted_string(rest)
    ['"', .. rest] => read_double_quoted_string(rest)
    ['.', .. rest] => read_frac(rest)
    [c, .. _rest] as code if c.is_ascii_digit() => read_number(code)
    ['_', .. _rest] as code => self.read_identifier_or_keyword(code)
    [c, .. _rest] as code if c.is_ascii_alphabetic() =>
      self.read_identifier_or_keyword(code)
    [c, .. _rest] => raise UnknownCharacter(c)
    [] => (Eof, [])
  }
}

///|
fn skip_whitespace(input : @string.View) -> @string.View {
  loop input {
    [c, .. rest] if c.is_ascii_whitespace() => continue rest
    input => break input
  }
}

///|
fn read_frac(input : @string.View) -> (Token, @string.View) {
  let (idx, rest) = loop (input, 0) {
    ([c, .. rest], n) if c.is_ascii_digit() => continue (rest, n + 1)
    (rest, n) => break (n, rest)
  }
  if idx == 0 {
    (Period, rest)
  } else {
    (Number("." + input.view(start_offset=0, end_offset=idx).to_string()), rest)
  }
}

///|
fn read_number(input : @string.View) -> (Token, @string.View) {
  let (idx, rest) = loop (input, 0) {
    ([c, .. rest], n) if c.is_ascii_digit() => continue (rest, n + 1)
    (rest, n) => break (n, rest)
  }
  let (idx, rest) = match rest {
    ['.', .. rest] =>
      loop (rest, idx + 1) {
        ([c, .. rest], n) if c.is_ascii_digit() => continue (rest, n + 1)
        (rest, n) => break (n, rest)
      }
    rest => (idx, rest)
  }
  (Number(input.view(start_offset=0, end_offset=idx).to_string()), rest)
}

///|
fn Lexer::read_identifier_or_keyword(
  self : Lexer,
  input : @string.View,
) -> (Token, @string.View) {
  let (idx, rest) = loop (input, 0) {
    ([c, .. rest], n) if is_ascii_alphabetic_or_digit(c) =>
      continue (rest, n + 1)
    (rest, n) => break (n, rest)
  }
  let token = match input.view(start_offset=0, end_offset=idx).to_lower() {
    "true" if self.dialect.supports_boolean_literals() => Token::Boolean(true)
    "false" if self.dialect.supports_boolean_literals() => Token::Boolean(false)
    "select" => Keyword(Select)
    "from" => Keyword(From)
    "where" => Keyword(Where)
    "as" => Keyword(As)
    "group" => Keyword(Group)
    "order" => Keyword(Order)
    "by" => Keyword(By)
    "asc" => Keyword(Asc)
    "desc" => Keyword(Desc)
    "nulls" => Keyword(Nulls)
    "first" => Keyword(First)
    "last" => Keyword(Last)
    "year" => Keyword(Year)
    "month" => Keyword(Month)
    "day" => Keyword(Day)
    "hour" => Keyword(Hour)
    "minute" => Keyword(Minute)
    "second" => Keyword(Second)
    "date" => Keyword(Date)
    "interval" => Keyword(Interval)
    "to" => Keyword(To)
    "like" => Keyword(Like)
    "not" => Keyword(Not)
    "ilike" => Keyword(ILike)
    "and" => Keyword(And)
    "or" => Keyword(Or)
    "exists" => Keyword(Exists)
    "between" => Keyword(Between)
    "extract" => Keyword(Extract)
    "case" => Keyword(Case)
    "when" => Keyword(When)
    "then" => Keyword(Then)
    "else" => Keyword(Else)
    "end" => Keyword(End)
    "having" => Keyword(Having)
    "in" => Keyword(In)
    "join" => Keyword(Join)
    "left" => Keyword(Left)
    "right" => Keyword(Right)
    "full" => Keyword(Full)
    "outer" => Keyword(Outer)
    "inner" => Keyword(Inner)
    "cross" => Keyword(Cross)
    "on" => Keyword(On)
    "using" => Keyword(Using)
    "limit" => Keyword(Limit)
    "offset" => Keyword(Offset)
    "create" => Keyword(Create)
    "table" => Keyword(Table)
    "integer" => Keyword(Integer)
    "int" => Keyword(Int)
    "smallint" => Keyword(Smallint)
    "bigint" => Keyword(Bigint)
    "real" => Keyword(Real)
    "double" => Keyword(Double)
    "precision" => Keyword(Precision)
    "char" => Keyword(Char)
    "character" => Keyword(Character)
    "varchar" => Keyword(Varchar)
    "varing" => Keyword(Varing)
    "text" => Keyword(Text)
    "time" => Keyword(Time)
    "boolean" => Keyword(Boolean)
    "float" => Keyword(Float)
    "timestamp" => Keyword(Timestamp)
    "blob" => Keyword(Blob)
    "null" => Keyword(Null)
    "default" => Keyword(Default)
    "unique" => Keyword(Unique)
    "view" => Keyword(View)
    "drop" => Keyword(Drop)
    "distinct" => Keyword(Distinct)
    "all" => Keyword(All)
    "substring" => Keyword(Substring)
    "for" => Keyword(For)
    "primary" => Keyword(Primary)
    "key" => Keyword(Key)
    "foreign" => Keyword(Foreign)
    "references" => Keyword(References)
    "check" => Keyword(Check)
    "union" => Keyword(Union)
    "intersect" => Keyword(Intersect)
    "except" => Keyword(Except)
    "top" => Keyword(Top)
    "insert" => Keyword(Insert)
    "into" => Keyword(Into)
    "values" => Keyword(Values)
    "if" => Keyword(If)
    "delete" => Keyword(Delete)
    "update" => Keyword(Update)
    "set" => Keyword(Set)
    "truncate" => Keyword(Truncate)
    word => Token::Identifier(word.to_string())
  }
  (token, rest)
}

///|
fn is_ascii_alphabetic_or_digit(ch : Char) -> Bool {
  ch.is_ascii_alphabetic() || ch.is_ascii_digit() || ch == '_'
}

///|
fn Lexer::read_single_quoted_string(
  self : Lexer,
  input : @string.View,
) -> (Token, @string.View) raise LexerError {
  let result = StringBuilder::new()
  let rest = loop input {
    [.. "''", .. rest] => {
      result.write_char('\'')
      continue rest
    }
    ['\'', .. rest] => break rest
    [.. "\\'", .. rest] if self.dialect.supports_string_literal_backslash_escape() => {
      result.write_char('\'')
      continue rest
    }
    [c, .. rest] => {
      result.write_char(c)
      continue rest
    }
    [] => raise LexerError::UnterminatedString
  }
  (StringLiteral(result.to_string()), rest)
}

///|
fn read_double_quoted_string(
  input : @string.View,
) -> (Token, @string.View) raise LexerError {
  let result = StringBuilder::new()
  let rest = loop input {
    [.. "\\\"", .. rest] => {
      result.write_char('\"')
      continue rest
    }
    ['"', .. rest] => break rest
    [c, .. rest] => {
      result.write_char(c)
      continue rest
    }
    [] => raise LexerError::UnterminatedString
  }
  (StringLiteral(result.to_string()), rest)
}

///|
test "Double quoted string" {
  let input = "\"Hello,\\\" World!\""
  let tokens = tokenize(input)
  inspect(
    tokens,
    content=(
      #|[StringLiteral("Hello,\" World!")]
    ),
  )
}

///|
fn skip_line_comment(input : @string.View) -> @string.View {
  loop input {
    ['\r' | '\n', .. rest] => break rest
    [_c, .. rest] => continue rest
    [] => break []
  }
}

///|
test "Lexing one keyword" {
  let input = "SELECT"
  let tokens = tokenize(input)
  inspect(tokens, content="[Keyword(Select)]")
}

///|
test "Lexing two keywords" {
  let input = "SELECT FROM"
  let tokens = tokenize(input)
  inspect(tokens, content="[Keyword(Select), Keyword(From)]")
}

///|
test "Lexing simple query" {
  let input = "SELECT * FROM table WHERE id = 1;"
  let tokens = tokenize(input)
  inspect(
    tokens,
    content=(
      #|[Keyword(Select), Mul, Keyword(From), Keyword(Table), Keyword(Where), Identifier("id"), Eq, Number("1"), Semicolon]
    ),
  )
}

///|
test "Lexing single quoted string" {
  let input = "SELECT 'Hello, World!' FROM t;"
  let tokens = tokenize(input)
  inspect(
    tokens,
    content=(
      #|[Keyword(Select), StringLiteral("Hello, World!"), Keyword(From), Identifier("t"), Semicolon]
    ),
  )
}

///|
test "Lexing single quoted string with escaped quotes" {
  let input = "SELECT 'Hello, ''World!''!' FROM t;"
  let tokens = tokenize(input)
  inspect(
    tokens,
    content=(
      #|[Keyword(Select), StringLiteral("Hello, 'World!'!"), Keyword(From), Identifier("t"), Semicolon]
    ),
  )
}

///|
test "Lexing binary operators" {
  let input = "< = > == <> <= >= <=>"
  let tokens = tokenize(input)
  inspect(tokens, content="[Lt, Eq, Gt, DoubleEq, Neq, LtEq, GtEq, Spaceship]")
}

///|
test "Skip line comment" {
  let input = "SELECT * FROM t -- This is a comment\n WHERE id = 1;\n --x \r -- Another comment \n"
  let tokens = tokenize(input)
  inspect(
    tokens,
    content=(
      #|[Keyword(Select), Mul, Keyword(From), Identifier("t"), Keyword(Where), Identifier("id"), Eq, Number("1"), Semicolon, Eof]
    ),
  )
}

///|
test "Skip line comment" {
  let input = "-- License: Apache-2.0\nSELECT * FROM t -- This is a comment\n WHERE id = 1;\n --x \r -- Another comment \n 123"
  let tokens = tokenize(input)
  inspect(
    tokens,
    content=(
      #|[Keyword(Select), Mul, Keyword(From), Identifier("t"), Keyword(Where), Identifier("id"), Eq, Number("1"), Semicolon, Number("123")]
    ),
  )
}

///|
test "Decimal point only" {
  let input = "123 . 123 .123 123.123 .1 1.1 22.22;"
  let tokens = tokenize(input)
  inspect(
    tokens,
    content=(
      #|[Number("123"), Period, Number("123"), Number(".123"), Number("123.123"), Number(".1"), Number("1.1"), Number("22.22"), Semicolon]
    ),
  )
}

///|
test "Decimal point" {
  let input = "SELECT 3.14, .11 FROM t;"
  let tokens = tokenize(input)
  inspect(
    tokens,
    content=(
      #|[Keyword(Select), Number("3.14"), Comma, Number(".11"), Keyword(From), Identifier("t"), Semicolon]
    ),
  )
}

///|
test "Complicated" {
  let input = "l_linestatus;\n"
  let tokens = tokenize(input)
  inspect(
    tokens,
    content=(
      #|[Identifier("l_linestatus"), Semicolon, Eof]
    ),
  )
}

///|
test "Single quoted string with escaped backslash" {
  let input = "SELECT 'Hello, \\'World!\\'' FROM t;"
  let tokens = tokenize(dialect=MySQL::{  }, input)
  inspect(
    tokens,
    content=(
      #|[Keyword(Select), StringLiteral("Hello, 'World!'"), Keyword(From), Identifier("t"), Semicolon]
    ),
  )
}
