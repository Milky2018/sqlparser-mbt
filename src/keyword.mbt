pub(all) enum Keyword {
  Select
  From
  Where
  As
  Group
  Order
  By
  Asc
  Desc
  Nulls
  First
  Last
  Year
  Month
  Day
  Hour
  Minute
  Second
  Date
  Interval
  To
  Like
  Not
  ILike
  // Only in lexer
  And
  Or
} derive(Eq, Show)