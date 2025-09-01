import extra
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pair
import gleam/result
import gleam/set
import sb/error.{type Error}
import sb/report.{type Report}

pub type Decoder(v) {
  Decoder(zero: fn() -> v, decode: fn(Dynamic) -> Result(v, Report(Error)))
}

fn run_decoder(
  dynamic: Dynamic,
  decoder: decode.Decoder(v),
) -> Result(v, Report(Error)) {
  decode.run(dynamic, decoder)
  |> report.map_error(error.DecodeError)
}

pub fn std_decoder(
  decoder: decode.Decoder(v),
) -> fn(Dynamic) -> Result(v, Report(Error)) {
  run_decoder(_, decoder)
}

pub const string = Decoder(zero: zero_string, decode: decode_string)

fn zero_string() {
  ""
}

pub fn decode_string(dynamic: Dynamic) -> Result(String, Report(Error)) {
  decode.run(dynamic, decode.string)
  |> report.map_error(error.DecodeError)
}

pub fn list(inner: decode.Decoder(v)) -> Decoder(List(v)) {
  Decoder(zero: fn() { [] }, decode: std_decoder(decode.list(inner)))
}

pub fn optional(inner: decode.Decoder(v)) -> Decoder(Option(v)) {
  Decoder(zero: fn() { None }, decode: std_decoder(decode.map(inner, Some)))
}

pub fn pairs(
  decoder: fn(Dynamic) -> Result(#(String, v), Report(Error)),
) -> Decoder(List(Result(#(String, v), Report(Error)))) {
  Decoder(zero: fn() { [] }, decode: fn(dynamic) {
    use list <- result.map(run_decoder(dynamic, decode.list(decode.dynamic)))
    use <- extra.return(pair.second)
    use seen, dynamic <- list.map_fold(list, set.new())
    error.try_duplicate_ids(decoder(dynamic), seen)
  })
}
