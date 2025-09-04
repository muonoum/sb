import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/option.{type Option, None, Some}
import sb/error.{type Error}
import sb/report.{type Report}

pub type Decoder(v) =
  fn(Dynamic) -> Result(v, Report(Error))

pub fn from(decoder: decode.Decoder(v)) -> Decoder(v) {
  fn(dynamic) {
    decode.run(dynamic, decoder)
    |> report.map_error(error.DecodeError)
  }
}

pub fn run(
  dynamic: Dynamic,
  decoder: decode.Decoder(v),
) -> Result(v, Report(Error)) {
  dynamic |> from(decoder)
}

pub type Zero(v) =
  #(v, Option(Report(Error)))

pub fn zero(
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

pub fn zero_string(decoder: Decoder(String)) -> fn(Dynamic) -> Zero(String) {
  use <- zero(decoder)
  ""
}

pub fn zero_bool(decoder: Decoder(Bool)) -> fn(Dynamic) -> Zero(Bool) {
  use <- zero(decoder)
  False
}

pub fn zero_list(decoder: Decoder(List(v))) -> fn(Dynamic) -> Zero(List(v)) {
  use <- zero(decoder)
  []
}

pub fn zero_option(
  decoder: Decoder(Option(v)),
) -> fn(Dynamic) -> Zero(Option(v)) {
  use <- zero(decoder)
  None
}
