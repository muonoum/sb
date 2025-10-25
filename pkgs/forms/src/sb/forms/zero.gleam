import gleam/dict.{type Dict}
import gleam/option.{type Option, None, Some}
import sb/forms/decoder.{type Decoder}

pub type Zero(v, err) {
  Value(value: v, decoder: Decoder(v))
  Try(value: fn() -> Result(v, err), decoder: Decoder(v))
}

pub fn value(zero: Zero(v, err)) -> Result(v, err) {
  case zero {
    Value(value:, ..) -> Ok(value)
    Try(value:, ..) -> value()
  }
}

pub fn new(value: v, decoder: Decoder(v)) -> Zero(v, err) {
  Value(value:, decoder:)
}

pub fn ok(value: fn() -> v, decoder: Decoder(v)) -> Zero(v, err) {
  use <- Try(value: _, decoder:)
  Ok(value())
}

pub fn error(error: err, decoder: Decoder(v)) -> Zero(v, err) {
  use <- Try(value: _, decoder:)
  Error(error)
}

pub fn try(value: fn() -> Result(v, err), decoder: Decoder(v)) -> Zero(v, err) {
  Try(value:, decoder:)
}

pub fn string(decoder: Decoder(String)) -> Zero(String, err) {
  new("", decoder)
}

pub fn bool(decoder: Decoder(Bool)) -> Zero(Bool, err) {
  new(False, decoder)
}

pub fn list(decoder: Decoder(List(v))) -> Zero(List(v), err) {
  new([], decoder)
}

pub fn dict(decoder: Decoder(Dict(k, v))) -> Zero(Dict(k, v), err) {
  new(dict.new(), decoder)
}

pub fn option(decoder: Decoder(v)) -> Zero(Option(v), err) {
  new(None, decoder.map(decoder, Some))
}
