///|
pub fn BinaryOperator::get_precedence(self : Self) -> Precedence {
  match self {
    BinaryOperator::Plus | BinaryOperator::Minus => Precedence::PlusMinus
    BinaryOperator::Mul | BinaryOperator::Div | BinaryOperator::Mod =>
      Precedence::MulDivMod
    BinaryOperator::Eq
    | BinaryOperator::Neq
    | BinaryOperator::Lt
    | BinaryOperator::Gt
    | BinaryOperator::LtEq
    | BinaryOperator::GtEq
    | BinaryOperator::Spaceship => Precedence::Eq
    BinaryOperator::And => Precedence::And
    BinaryOperator::Or => Precedence::Or
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
  }
}
