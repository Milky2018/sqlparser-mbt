///|
pub suberror SqlParserError {
  LexerError(LexerError)
  ParserError(ParserError)
} derive(Show)

///|
pub fn parse_sql(input : String) -> Statements raise SqlParserError {
  let lexer = Lexer::new(input)
  let tokens = lexer.lex() catch { e => raise SqlParserError::LexerError(e) }
  let parser = Parser::new(tokens)
  let stmts = parser.parse() catch { e => raise SqlParserError::ParserError(e) }
  { stmts, }
}
