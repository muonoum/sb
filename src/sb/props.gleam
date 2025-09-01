import extra/state.{type State}
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import sb/decoder.{type Decoder}
import sb/error.{type Error}
import sb/report.{type Report}

pub type PropertyDecoder(v) {
  RequiredDecoder(decode: Decoder(v))
  DefaultDecoder(default: fn() -> v, decode: Decoder(v))
}

pub type Props(v) =
  State(v, Report(Error), Dict(String, Dynamic))

pub fn decode(dynamic: Dynamic, decoder: Props(v)) -> Result(v, Report(Error)) {
  state.run(context: dict.new(), state: {
    use <- load(dynamic)
    decoder
  })
}

pub fn check_keys(keys: List(String)) -> Props(Nil) {
  use dict <- state.with(state.get())
  state.from_result(error.unknown_keys(dict, keys))
  |> state.replace(Nil)
}

pub fn load(dynamic: Dynamic, next: fn() -> Props(v)) -> Props(v) {
  let result =
    decode.run(dynamic, decode.dict(decode.string, decode.dynamic))
    |> report.map_error(error.DecodeError)

  case result {
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
