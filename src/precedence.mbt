///|
pub fn BinaryOperator::get_precedence(self : Self) -> Precedence {
  match self {
    BinaryOperator::Plus | BinaryOperator::Minus => Precedence::PlusMinus
    BinaryOperator::Mul
    | BinaryOperator::Div
    | BinaryOperator::IntegerDiv
    | BinaryOperator::Mod => Precedence::MulDivMod
    BinaryOperator::Eq
    | BinaryOperator::Neq
    | BinaryOperator::Lt
    | BinaryOperator::Gt
    | BinaryOperator::LtEq
    | BinaryOperator::GtEq
    | BinaryOperator::Spaceship => Precedence::Eq
    BinaryOperator::And => Precedence::And
    BinaryOperator::Or => Precedence::Or
    // PostgreSQL JSON operators - higher precedence than comparison
    BinaryOperator::JsonExtract
    | BinaryOperator::JsonExtractText
    | BinaryOperator::JsonExtractPath
    | BinaryOperator::JsonExtractPathText
    | BinaryOperator::JsonContains
    | BinaryOperator::JsonContainedIn => Precedence::JsonOperator
  }
}

///|
pub(all) enum Precedence {
  PlusMinus
  MulDivMod
  Eq
  Like
  And
  Or
  Between
  UnaryNot
  JsonOperator
}

///|
pub fn Precedence::value(self : Precedence) -> Int {
  match self {
    And => 10
    Like => 19
    Eq => 20
    MulDivMod => 40
    PlusMinus => 30
    Or => 5
    Between => 20
    UnaryNot => 15
    JsonOperator => 35 // Between PlusMinus and MulDivMod
  }
}
