///|
pub suberror SqlParserError {
  LexerError(LexerError)
  ParserError(ParserError)
} derive(Show)

///|
pub fn parse_sql(input : String) -> Statement raise SqlParserError {
  let lexer = Lexer::new(input)
  let tokens = lexer.lex() catch { e => raise SqlParserError::LexerError(e) }
  let parser = Parser::new(tokens)
  let stmt = parser.parse() catch { e => raise SqlParserError::ParserError(e) }
  stmt
}
