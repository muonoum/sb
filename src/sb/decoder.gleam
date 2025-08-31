import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import sb/error.{type Error}
import sb/report.{type Report}

pub type Decoder(v) =
  fn(Dynamic) -> Result(v, Report(Error))

pub fn run(decoder: decode.Decoder(v)) -> Decoder(v) {
  fn(dynamic) {
    decode.run(dynamic, decoder)
    |> report.map_error(error.DecodeError)
  }
}
