import gleam/dynamic/decode
import gleam/json.{type Json}
import gleam/list

pub type Value {
  String(String)
  List(List(Value))
  Object(List(#(String, Value)))
}

pub fn string_list(strings: List(String)) -> Value {
  List(list.map(strings, String))
}

pub fn to_string(value: Value) -> Result(String, Nil) {
  case value {
    String(string) -> Ok(string)
    _value -> Error(Nil)
  }
}

pub fn to_json(_value: Value) -> Json {
  todo
}

pub fn decoder() -> decode.Decoder(Value) {
  todo
}
