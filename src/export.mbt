///|
pub suberror SqlParserError {
  LexerError(LexerError)
  ParserError(ParserError)
} derive(Show)

///|
pub fn parse_sql(
  dialect~ : &Dialect = MySQL::{  },
  input : String,
) -> Statements raise SqlParserError {
  let tokens = tokenize(dialect~, input) catch {
    e => raise SqlParserError::LexerError(e)
  }
  let stmts = parse(dialect~, tokens) catch {
    e => raise SqlParserError::ParserError(e)
  }
  { stmts, }
}
