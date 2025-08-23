pub type Value {
  String(String)
  List(List(Value))
  Object(List(#(String, Value)))
}

pub fn to_string(value: Value) -> Result(String, Nil) {
  case value {
    String(string) -> Ok(string)
    _value -> Error(Nil)
  }
}
