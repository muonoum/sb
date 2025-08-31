import extra/state.{type State}
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import sb/error.{type Error}
import sb/report.{type Report}

pub type Props(v) =
  State(v, Report(Error), Dict(String, Dynamic))

pub type Decoder(v) =
  fn(Dynamic) -> Result(v, Report(Error))

// TODO: Hører ikke hjemme her?
pub fn run_decoder(decoder: decode.Decoder(v)) -> Decoder(v) {
  fn(dynamic) {
    decode.run(dynamic, decoder)
    |> report.map_error(error.DecodeError)
  }
}

pub fn decode(dynamic: Dynamic, decoder: Props(v)) -> Result(v, Report(Error)) {
  state.run(context: dict.new(), state: {
    use <- load(dynamic)
    decoder
  })
}

pub fn check_unknown_keys(keys: List(String)) -> Props(Nil) {
  use dict <- state.with(state.get())
  error.unknown_keys(dict, keys)
  |> state.from_result
  |> state.replace(Nil)
}

pub fn load(dynamic: Dynamic, next: fn() -> Props(v)) -> Props(v) {
  let decoder = run_decoder(decode.dict(decode.string, decode.dynamic))

  case decoder(dynamic) {
    Error(report) -> state.fail(report)
    Ok(dict) -> state.do(state.put(dict), next)
  }
}

pub fn succeed(value: v) -> Props(v) {
  state.succeed(value)
}

pub fn fail(report: Report(Error)) -> Props(v) {
  state.fail(report)
}

pub fn field(
  name: String,
  decoder: Decoder(a),
  next: fn(a) -> Props(b),
) -> Props(b) {
  let error = report.error(error.MissingProperty(name))
  default_field(name, error, decoder, next)
}

pub fn default_field(
  name: String,
  default: Result(a, Report(Error)),
  decoder: Decoder(a),
  next: fn(a) -> Props(b),
) -> Props(b) {
  use dict <- state.with(state.get())

  let result = case dict.get(dict, name) {
    Error(Nil) -> default

    Ok(dynamic) ->
      decoder(dynamic)
      |> report.error_context(error.BadProperty(name))
  }

  case result {
    Error(report) -> state.fail(report)
    Ok(value) -> state.with(state.succeed(value), next)
  }
}
// fn decode_list(
//   decoder: Decoder(v),
// ) -> fn(Dynamic) -> Result(List(v), Report(Error)) {
//   fn(dynamic) {
//     decode_run(dynamic, decode.list(decode.dynamic))
//     |> result.try(list.try_map(_, decoder))
//   }
// }
