import sb/parser
import sb/value.{type Value}

pub type Error {
  Required

  BadId(String)
  BadKind
  BadProperty(String)
  BadSource
  BadValue(Value)

  TextError(parser.Message(String))
}
