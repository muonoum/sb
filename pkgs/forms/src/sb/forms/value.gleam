import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode.{type Decoder}
import gleam/float
import gleam/int
import gleam/json.{type Json}
import gleam/list
import gleam/option.{None, Some}
import gleam/string

pub type Value {
  Null
  Bool(Bool)
  Float(Float)
  Int(Int)
  String(String)
  List(List(Value))
  Pair(String, Value)
  Object(List(#(String, Value)))
}

pub fn to_string(value: Value) -> String {
  case value {
    String(string) -> string
    Null -> "null"
    Int(v) -> int.to_string(v)
    Float(v) -> float.to_string(v)
    Bool(True) -> "true"
    Bool(False) -> "false"
    // TODO
    Pair(..) -> json.to_string(to_json(value))
    List(..) -> json.to_string(to_json(value))
    Object(..) -> json.to_string(to_json(value))
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

    Pair(key, value) -> json.object([#(key, to_json(value))])

    Object(pairs) ->
      json.object({
        use #(key, value) <- list.map(pairs)
        #(key, to_json(value))
      })
  }
}

// TODO: Spesialbehandler objekter med bare ett medlem for å støtte
// options som [a: 1, b, c] -> keys: [a, b, c]. Kan det bli problematisk
// hvis vi f.eks. tilfeldigvis får en sånn struktur i en fetch-respons
// som vi vil vise som options?
pub fn key(value: Value) -> Value {
  case value {
    Pair(key, _value) -> String(key)
    value -> value
  }
}

pub fn keys(value: Value) -> Result(List(Value), Nil) {
  case value {
    Null -> Error(Nil)
    Bool(..) -> Error(Nil)
    Float(..) -> Error(Nil)
    Int(..) -> Error(Nil)
    String(..) -> Error(Nil)
    Pair(..) -> Error(Nil)

    List(values) -> Ok(list.map(values, key))

    Object(pairs) ->
      Ok({
        use #(key, _value) <- list.map(pairs)
        String(key)
      })
  }
}

pub fn match(value: Value, term: String) -> Bool {
  let term = string.lowercase(term)

  case value {
    Null -> string.contains("null", term)

    String(string) -> {
      let string = string.lowercase(string)
      string.contains(string, term)
    }

    List(list) -> list.any(list, match(_, term))

    Pair(key, _value) ->
      String(key)
      |> match(term)

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
    decode.map(decode.list(recursive()), List),
    pair_decoder(),
    decode.map(dict_decoder(), Object),
  ])
}

fn recursive() -> Decoder(Value) {
  decode.recursive(decoder)
}

fn null_decoder() -> Decoder(Value) {
  use value <- decode.then(decode.optional(decode.dynamic))

  case value {
    None -> decode.success(Null)
    Some(value) -> decode.failure(Null, dynamic.classify(value))
  }
}

fn pair_decoder() -> decode.Decoder(Value) {
  use #(key, value) <- decode.then(key_value_decoder())
  decode.success(Pair(key, value))
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
  decode.dict(decode.string, recursive())
  |> decode.map(dict.to_list)
}
