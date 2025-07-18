///|
pub suberror SqlParserError {
  LexerError(LexerError)
  ParserError(ParserError)
} derive(Show)

///|
pub fn parse_sql(input : String) -> Statements raise SqlParserError {
  let tokens = lex(input) catch { e => raise SqlParserError::LexerError(e) }
  let stmts = parse(tokens) catch { e => raise SqlParserError::ParserError(e) }
  { stmts, }
}
