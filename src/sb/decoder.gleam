import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
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
