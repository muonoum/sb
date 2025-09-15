import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode.{type Decoder}
import gleam/float
import gleam/int
import gleam/json.{type Json}
import gleam/list
import gleam/option.{None, Some}
import gleam/pair
import gleam/string

pub type Value {
  Null
  Bool(Bool)
  Float(Float)
  Int(Int)
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

// TODO
pub fn keys(value: Value) -> Result(List(Value), Nil) {
  case value {
    List(list) -> Ok(list)
    Object(pairs) -> Ok(list.map(pairs, pair.first) |> list.map(String))
    _value -> Error(Nil)
  }
}

// TODO
pub fn match(value: Value, term: String) -> Bool {
  let term = string.lowercase(term)

  case value {
    Null -> False

    String(string) -> {
      let string = string.lowercase(string)
      string.contains(string, term)
    }

    List(list) -> list.any(list, match(_, term))

    Object(list) -> {
      use #(key, value) <- list.any(list)
      let key = string.lowercase(key)
      string.contains(key, term) || match(value, term)
    }

    Bool(True) -> string.contains("true", term)
    Bool(False) -> string.contains("false", term)
    Float(int) -> string.contains(float.to_string(int), term)
    Int(int) -> string.contains(int.to_string(int), term)
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
