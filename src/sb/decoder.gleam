import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/result
import sb/error.{type Error}
import sb/report.{type Report}

pub type Decoder(v) =
  fn(Dynamic) -> Result(v, Report(Error))

pub fn new(decoder: decode.Decoder(v)) -> Decoder(v) {
  fn(dynamic) {
    decode.run(dynamic, decoder)
    |> report.map_error(error.DecodeError)
  }
}

pub fn run(
  dynamic: Dynamic,
  decoder: decode.Decoder(v),
) -> Result(v, Report(Error)) {
  dynamic |> new(decoder)
}

pub fn list_decoder(
  decoder: Decoder(v),
) -> fn(Dynamic) -> Result(List(v), Report(Error)) {
  fn(dynamic) {
    run(dynamic, decode.list(decode.dynamic))
    |> result.try(list.try_map(_, decoder))
  }
}

pub fn decode_list(
  dynamic: Dynamic,
  decoder: Decoder(v),
) -> Result(List(v), Report(Error)) {
  dynamic |> list_decoder(decoder)
}
