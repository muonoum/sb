import gleam/option.{type Option, None, Some}
import sb/forms/decoder.{type Decoder}

pub type Zero(v) {
  Zero(value: v, decoder: Decoder(v))
  Lazy(value: fn() -> v, decoder: Decoder(v))
}

pub fn value(zero: Zero(v)) -> v {
  case zero {
    Zero(value:, ..) -> value
    Lazy(value:, ..) -> value()
  }
}

pub fn new(value: v, decoder: Decoder(v)) -> Zero(v) {
  Zero(value:, decoder:)
}

pub fn lazy(value: fn() -> v, decoder: Decoder(v)) -> Zero(v) {
  Lazy(value:, decoder:)
}

pub fn string(decoder: Decoder(String)) -> Zero(String) {
  new("", decoder)
}

pub fn bool(decoder: Decoder(Bool)) -> Zero(Bool) {
  new(False, decoder)
}

pub fn list(decoder: Decoder(List(v))) -> Zero(List(v)) {
  new([], decoder)
}

pub fn option(decoder: Decoder(v)) -> Zero(Option(v)) {
  new(None, decoder.map(decoder, Some))
}
