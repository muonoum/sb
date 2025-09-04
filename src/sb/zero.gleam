import gleam/dynamic.{type Dynamic}
import gleam/option.{type Option, None, Some}
import sb/decoder.{type Decoder}
import sb/error.{type Error}
import sb/report.{type Report}

pub type Zero(v) =
  #(v, Option(Report(Error)))

pub fn new(
  decoder: Decoder(v),
  zero: fn() -> v,
) -> fn(Dynamic) -> #(v, Option(Report(Error))) {
  fn(dynamic) {
    case decoder(dynamic) {
      Error(report) -> #(zero(), Some(report))
      Ok(value) -> #(value, None)
    }
  }
}

pub fn string(decoder: decoder.Decoder(String)) -> fn(Dynamic) -> Zero(String) {
  new(decoder, fn() { "" })
}

pub fn bool(decoder: Decoder(Bool)) -> fn(Dynamic) -> Zero(Bool) {
  new(decoder, fn() { False })
}

pub fn list(decoder: Decoder(List(v))) -> fn(Dynamic) -> Zero(List(v)) {
  new(decoder, fn() { [] })
}

pub fn option(decoder: Decoder(Option(v))) -> fn(Dynamic) -> Zero(Option(v)) {
  new(decoder, fn() { None })
}
