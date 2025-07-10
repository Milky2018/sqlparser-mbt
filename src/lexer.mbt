///|
suberror LexerError {}

///|
pub(all) enum Token {
  Select
  From
  Where
  As
  Identifier(String)
  Number(String)
  StringLiteral(String)
  Comma
  Semicolon
  Eq
  DoubelEq
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
  Unknown(Char)
  Eof
} derive(Eq, Show)

///|
struct Lexer {
  mut offset : Int
  input : String
  end_offset : Int
}

///|
pub fn Lexer::new(input : String) -> Lexer {
  { offset: 0, input, end_offset: input.length() }
}

///|
pub fn Lexer::lex(self : Self) -> Array[Token] {
  let tokens = []
  while self.offset < self.end_offset {
    let token = self.next_token()
    if token == Token::Eof {
      break
    }
    tokens.push(token)
  }
  tokens
}

///|
fn Lexer::current(self : Self) -> Char {
  self.input.char_at(self.offset)
}

///|
fn Lexer::next_token(self : Self) -> Token {
  self.skip_whitespace()
  let token = match self.current() {
    ',' => {
      self.offset += 1
      Comma
    }
    ';' => {
      self.offset += 1
      Semicolon
    }
    '*' => {
      self.offset += 1
      Mul
    }
    '=' => {
      self.offset += 1
      if self.current() == '=' {
        self.offset += 1
        DoubelEq
      } else {
        Eq
      }
    }
    '<' => {
      self.offset += 1
      if self.current() == '>' {
        self.offset += 1
        Neq
      } else if self.current() == '=' {
        self.offset += 1
        if self.current() == '>' {
          self.offset += 1
          Spaceship
        } else {
          LtEq
        }
      } else {
        Lt
      }
    }
    '>' => {
      self.offset += 1
      if self.current() == '=' {
        self.offset += 1
        GtEq
      } else {
        Gt
      }
    }
    '!' => {
      self.offset += 1
      if self.current() == '=' {
        self.offset += 1
        Neq
      } else {
        Unknown('!')
      }
    }
    '+' => {
      self.offset += 1
      Plus
    }
    '-' => {
      self.offset += 1
      Minus
    }
    '/' => {
      self.offset += 1
      Div
    }
    '%' => {
      self.offset += 1
      Mod
    }
    '(' => {
      self.offset += 1
      LParen
    }
    ')' => {
      self.offset += 1
      RParen
    }
    '[' => {
      self.offset += 1
      LBracket
    }
    ']' => {
      self.offset += 1
      RBracket
    }
    '{' => {
      self.offset += 1
      LBrace
    }
    '}' => {
      self.offset += 1
      RBrace
    }
    '\'' => self.read_single_quoted_string()
    c if c.is_ascii_digit() => self.read_number()
    c if c.is_ascii_alphabetic() || c == '_' =>
      self.read_identifier_or_keyword()
    _ => panic()
  }
  token
}

///|
fn Lexer::skip_whitespace(self : Self) -> Unit {
  while self.offset < self.end_offset &&
        self.input.char_at(self.offset).is_whitespace() {
    self.offset += 1
  }
}

///|
fn Lexer::read_number(self : Self) -> Token {
  let start = self.offset
  while self.offset < self.end_offset && self.current().is_ascii_digit() {
    self.offset += 1
  }
  let end = self.offset
  Token::Number(self.input.substring(start~, end~))
}

///|
fn Lexer::read_identifier_or_keyword(self : Self) -> Token {
  let start = self.offset
  while self.offset < self.end_offset &&
        is_ascii_alphabetic_or_digit(self.current()) {
    self.offset += 1
  }
  let end = self.offset
  let word = self.input.substring(start~, end~).to_lower()
  match word {
    "select" => Token::Select
    "from" => Token::From
    "where" => Token::Where
    "as" => Token::As
    _ => Token::Identifier(word)
  }
}

///|
fn is_ascii_alphabetic_or_digit(ch : Char) -> Bool {
  ch.is_ascii_alphabetic() || ch.is_ascii_digit() || ch == '_'
}

///|
fn Lexer::read_single_quoted_string(self : Self) -> Token {
  self.offset += 1
  let result = StringBuilder::new()
  while self.offset < self.end_offset {
    match self.current() {
      '\'' => {
        self.offset += 1
        if self.offset < self.end_offset && self.current() == '\'' {
          result.write_char('\'')
          self.offset += 1
        } else {
          break
        }
      }
      c => {
        result.write_char(c)
        self.offset += 1
      }
    }
  }
  Token::StringLiteral(result.to_string())
}

///|
fn Lexer::read_double_quoted_string(self : Self) -> Token {
  self.offset += 1
  let result = StringBuilder::new()
  while self.offset < self.end_offset {
    match self.current() {
      '"' => {
        self.offset += 1
        if self.offset < self.end_offset && self.current() == '"' {
          result.write_char('"')
          self.offset += 1
        } else {
          break
        }
      }
      c => {
        result.write_char(c)
        self.offset += 1
      }
    }
  }
  Token::StringLiteral(result.to_string())
}

///|
test "Lexing one keyword" {
  let input = "SELECT"
  let lexer = Lexer::new(input)
  let tokens = lexer.lex()
  inspect(tokens, content="[Select]")
}

///|
test "Lexing two keywords" {
  let input = "SELECT FROM"
  let lexer = Lexer::new(input)
  let tokens = lexer.lex()
  inspect(tokens, content="[Select, From]")
}

///|
test "Lexing simple query" {
  let input = "SELECT * FROM table WHERE id = 1;"
  let lexer = Lexer::new(input)
  let tokens = lexer.lex()
  inspect(
    tokens,
    content="[Select, Mul, From, Identifier(\"table\"), Where, Identifier(\"id\"), Equals, Number(\"1\"), Semicolon]",
  )
}

///|
test "Lexing single quoted string" {
  let input = "SELECT 'Hello, World!' FROM table;"
  let lexer = Lexer::new(input)
  let tokens = lexer.lex()
  inspect(
    tokens,
    content="[Select, StringLiteral(\"Hello, World!\"), From, Identifier(\"table\"), Semicolon]",
  )
}

///|
test "Lexing single quoted string with escaped quotes" {
  let input = "SELECT 'Hello, ''World!''!' FROM table;"
  let lexer = Lexer::new(input)
  let tokens = lexer.lex()
  inspect(
    tokens,
    content="[Select, StringLiteral(\"Hello, 'World!'!\"), From, Identifier(\"table\"), Semicolon]",
  )
}

///|
test "Lexing binary operators" {
  let input = "< = > == != <> <= >= <=>"
  let lexer = Lexer::new(input)
  let tokens = lexer.lex()
  inspect(
    tokens,
    content="[Lt, Eq, Gt, DoubelEq, Neq, Neq, LtEq, GtEq, Spaceship]",
  )
}
