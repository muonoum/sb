import sb/value.{type Value}

pub type Error {
  Required

  BadId(String)
  BadKind
  BadSource
  BadValue(Value)
}
