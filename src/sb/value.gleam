import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode.{type Decoder}
import gleam/json.{type Json}
import gleam/list
import gleam/option.{None, Some}

pub type Value {
  Null
  Bool(Bool)
  Float(Float)
  Int(Int)
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

pub fn to_json(value: Value) -> Json {
  case value {
    Null -> json.null()
    Int(int) -> json.int(int)
    Bool(bool) -> json.bool(bool)
    Float(float) -> json.float(float)
    String(string) -> json.string(string)
    List(values) -> json.array(values, to_json)

    Object(pairs) ->
      json.object({
        use #(key, value) <- list.map(pairs)
        #(key, to_json(value))
      })
  }
}

pub fn decoder() -> Decoder(Value) {
  decode.one_of(null_decoder(), [
    decode.map(decode.bool, Bool),
    decode.map(decode.float, Float),
    decode.map(decode.int, Int),
    decode.map(decode.string, String),
    decode.map(decode.list(key_value_decoder()), Object),
    decode.map(decode.list(decode.recursive(decoder)), List),
    decode.map(dict_decoder(), Object),
  ])
}

fn null_decoder() -> Decoder(Value) {
  use value <- decode.then(decode.optional(decode.dynamic))

  case value {
    None -> decode.success(Null)
    Some(value) -> decode.failure(Null, dynamic.classify(value))
  }
}

fn key_value_decoder() -> Decoder(#(String, Value)) {
  use pairs <- decode.then(dict_decoder())

  case pairs {
    [] -> decode.failure(#("", Null), "key and value")
    [#(key, value)] -> decode.success(#(key, value))
    _multiple -> decode.failure(#("", Null), "key and value")
  }
}

fn dict_decoder() -> Decoder(List(#(String, Value))) {
  decode.dict(decode.string, decode.recursive(decoder))
  |> decode.map(dict.to_list)
}
