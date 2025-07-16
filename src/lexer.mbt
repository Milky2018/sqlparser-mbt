///|
suberror LexerError {
  InternalBug(String)
} derive(Show)

///|
pub(all) enum Token {
  Keyword(Keyword)
  Identifier(String)
  Number(String)
  StringLiteral(String)
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
  Unknown(Char)
  Eof
} derive(Eq, Show)

///|
struct Lexer {
  mut offset : Int
  input : String
}

///|
pub fn Lexer::new(input : String) -> Lexer {
  { offset: 0, input }
}

///|
pub fn Lexer::lex(self : Self) -> Array[Token] raise LexerError {
  let tokens = []
  while self.offset < self.input.length() {
    let token = self.next_token()
    if token == Token::Eof {
      break
    }
    tokens.push(token)
  }
  tokens
}

///|
fn Lexer::current(self : Self) -> Char? {
  if self.offset >= self.input.length() {
    return None
  } else {
    Some(self.input.char_at(self.offset))
  }
}

///|
fn Lexer::advance(self : Self) -> Unit {
  self.offset += 1
}

///|
fn Lexer::next_token(self : Self) -> Token raise LexerError {
  self.skip_whitespace()
  match self.current() {
    Some(',') => {
      self.advance()
      Comma
    }
    Some(';') => {
      self.advance()
      Semicolon
    }
    Some('*') => {
      self.advance()
      Mul
    }
    Some('=') => {
      self.advance()
      if self.current() == Some('=') {
        self.advance()
        DoubleEq
      } else {
        Eq
      }
    }
    Some('<') => {
      self.advance()
      if self.current() == Some('>') {
        self.advance()
        Neq
      } else if self.current() == Some('=') {
        self.advance()
        if self.current() == Some('>') {
          self.advance()
          Spaceship
        } else {
          LtEq
        }
      } else {
        Lt
      }
    }
    Some('>') => {
      self.advance()
      if self.current() == Some('=') {
        self.advance()
        GtEq
      } else {
        Gt
      }
    }
    Some('!') => {
      self.advance()
      if self.current() == Some('=') {
        self.advance()
        Neq
      } else {
        Unknown('!')
      }
    }
    Some('+') => {
      self.advance()
      Plus
    }
    Some('-') => {
      self.advance()
      if self.current() == Some('-') {
        self.advance()
        self.skip_line_comment()
        return self.next_token()
      } else {
        Minus
      }
    }
    Some('/') => {
      self.advance()
      Div
    }
    Some('%') => {
      self.advance()
      Mod
    }
    Some('(') => {
      self.advance()
      LParen
    }
    Some(')') => {
      self.advance()
      RParen
    }
    Some('[') => {
      self.advance()
      LBracket
    }
    Some(']') => {
      self.advance()
      RBracket
    }
    Some('{') => {
      self.advance()
      LBrace
    }
    Some('}') => {
      self.advance()
      RBrace
    }
    Some('\'') => self.read_single_quoted_string()
    Some('"') => self.read_double_quoted_string()
    Some('.') => self.read_frac()
    Some(c) if c.is_ascii_digit() => self.read_number()
    Some(c) if c.is_ascii_alphabetic() || c == '_' =>
      self.read_identifier_or_keyword()
    Some(c) => raise LexerError::InternalBug("Unexpected character: \{c}")
    None => Eof
  }
}

///|
fn Lexer::skip_whitespace(self : Self) -> Unit {
  while self.current().map_or(false, c => c.is_ascii_whitespace()) {
    self.advance()
  }
}

///|
fn Lexer::read_frac(self : Self) -> Token {
  let start = self.offset
  self.advance()
  while self.current().map_or(false, c => c.is_ascii_digit()) {
    self.advance()
  }
  let end = self.offset
  if end == start + 1 {
    return Token::Period
  }
  Token::Number(self.input.substring(start~, end~))
}

///|
fn Lexer::read_number(self : Self) -> Token {
  let start = self.offset
  while self.current().map_or(false, c => c.is_ascii_digit()) {
    self.advance()
  }
  if self.current() == Some('.') {
    self.advance()
    while self.current().map_or(false, c => c.is_ascii_digit()) {
      self.advance()
    }
  }
  let end = self.offset
  Token::Number(self.input.substring(start~, end~))
}

///|
fn Lexer::read_identifier_or_keyword(self : Self) -> Token {
  let start = self.offset
  while self.current().map_or(false, is_ascii_alphabetic_or_digit) {
    self.advance()
  }
  let end = self.offset
  let word = self.input.substring(start~, end~).to_lower()
  match word {
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
    _ => Token::Identifier(word)
  }
}

///|
fn is_ascii_alphabetic_or_digit(ch : Char) -> Bool {
  ch.is_ascii_alphabetic() || ch.is_ascii_digit() || ch == '_'
}

///|
fn Lexer::read_single_quoted_string(self : Self) -> Token {
  self.advance()
  let result = StringBuilder::new()
  for {
    match self.current() {
      Some('\'') => {
        self.advance()
        if self.current() == Some('\'') {
          result.write_char('\'')
          self.advance()
        } else {
          break
        }
      }
      Some(c) => {
        result.write_char(c)
        self.advance()
      }
      None => break
    }
  }
  Token::StringLiteral(result.to_string())
}

///|
fn Lexer::read_double_quoted_string(self : Self) -> Token {
  self.advance()
  let result = StringBuilder::new()
  for {
    match self.current() {
      Some('"') => {
        self.advance()
        if self.current() == Some('"') {
          result.write_char('"')
          self.advance()
        } else {
          break
        }
      }
      Some(c) => {
        result.write_char(c)
        self.advance()
      }
      None => break
    }
  }
  Token::StringLiteral(result.to_string())
}

///|
fn Lexer::skip_line_comment(self : Self) -> Unit {
  while not(self.current().map_or(true, c => c == '\n' || c == '\r')) {
    self.advance()
  }
}

///|
test "Lexing one keyword" {
  let input = "SELECT"
  let lexer = Lexer::new(input)
  let tokens = lexer.lex()
  inspect(tokens, content="[Keyword(Select)]")
}

///|
test "Lexing two keywords" {
  let input = "SELECT FROM"
  let lexer = Lexer::new(input)
  let tokens = lexer.lex()
  inspect(tokens, content="[Keyword(Select), Keyword(From)]")
}

///|
test "Lexing simple query" {
  let input = "SELECT * FROM table WHERE id = 1;"
  let lexer = Lexer::new(input)
  let tokens = lexer.lex()
  inspect(
    tokens,
    content=(
      #|[Keyword(Select), Mul, Keyword(From), Identifier("table"), Keyword(Where), Identifier("id"), Eq, Number("1"), Semicolon]
    ),
  )
}

///|
test "Lexing single quoted string" {
  let input = "SELECT 'Hello, World!' FROM table;"
  let lexer = Lexer::new(input)
  let tokens = lexer.lex()
  inspect(
    tokens,
    content=(
      #|[Keyword(Select), StringLiteral("Hello, World!"), Keyword(From), Identifier("table"), Semicolon]
    ),
  )
}

///|
test "Lexing single quoted string with escaped quotes" {
  let input = "SELECT 'Hello, ''World!''!' FROM table;"
  let lexer = Lexer::new(input)
  let tokens = lexer.lex()
  inspect(
    tokens,
    content=(
      #|[Keyword(Select), StringLiteral("Hello, 'World!'!"), Keyword(From), Identifier("table"), Semicolon]
    ),
  )
}

///|
test "Lexing binary operators" {
  let input = "< = > == != <> <= >= <=>"
  let lexer = Lexer::new(input)
  let tokens = lexer.lex()
  inspect(
    tokens,
    content="[Lt, Eq, Gt, DoubleEq, Neq, Neq, LtEq, GtEq, Spaceship]",
  )
}

///|
test "Skip line comment" {
  let input = "SELECT * FROM table -- This is a comment\n WHERE id = 1; -- Another comment"
  let lexer = Lexer::new(input)
  let tokens = lexer.lex()
  inspect(
    tokens,
    content=(
      #|[Keyword(Select), Mul, Keyword(From), Identifier("table"), Keyword(Where), Identifier("id"), Eq, Number("1"), Semicolon]
    ),
  )
}

///|
test "Decimal point" {
  let input = "SELECT 3.14, .1 FROM table;"
  let lexer = Lexer::new(input)
  let tokens = lexer.lex()
  inspect(
    tokens,
    content=(
      #|[Keyword(Select), Number("3.14"), Comma, Number(".1"), Keyword(From), Identifier("table"), Semicolon]
    ),
  )
}
