import extra/state.{type State}
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/result
import sb/dekode.{type Decoder}
import sb/error.{type Error}
import sb/report.{type Report}

pub type Context =
  Dict(String, Dynamic)

pub fn get(
  then: fn(Context) -> State(v, e, dekode.Context(Context)),
) -> State(v, e, dekode.Context(Context)) {
  use dict <- dekode.get()
  then(dict)
}

pub fn decode(
  dynamic: Dynamic,
  keys: List(List(String)),
  decoder: State(v, List(Report(Error)), dekode.Context(Context)),
) -> Result(v, List(Report(Error))) {
  dekode.Context(dict.new(), reports: [])
  |> state.run(context: _, state: {
    use <- load(dynamic, keys)
    decoder
  })
}

pub fn load(
  dynamic: Dynamic,
  keys: List(List(String)),
  then: fn() -> State(v, List(Report(Error)), dekode.Context(Context)),
) -> State(v, List(Report(Error)), dekode.Context(Context)) {
  decode.run(dynamic, decode.dict(decode.string, decode.dynamic))
  |> report.map_error(error.DecodeError)
  |> result.try(error.unknown_keys(_, keys))
  |> dekode.required(dekode.put(_, then))
}

pub fn property(
  name: String,
  decoder: Decoder(v),
  default: fn() -> Result(v, Report(Error)),
) -> State(v, c, dekode.Context(Context)) {
  use dict <- dekode.get()
  let dekode.Decoder(zero:, decoder:) = decoder

  let result = case dict.get(dict, name) {
    Error(Nil) -> default()

    Ok(dynamic) ->
      decoder(dynamic)
      |> report.error_context(error.BadProperty(name))
  }

  case result {
    Ok(value) -> state.succeed(value)

    Error(report) -> {
      use <- dekode.report(report)
      state.succeed(zero)
    }
  }
}

pub fn required(
  name: String,
  decoder: Decoder(a),
  then: fn(a) -> State(b, e, dekode.Context(Context)),
) -> State(b, e, dekode.Context(Context)) {
  state.do(then:, with: {
    use <- property(name, decoder)
    report.error(error.MissingProperty(name))
  })
}

pub fn zero(
  name: String,
  decoder: Decoder(a),
  then: fn(a) -> State(b, List(Report(Error)), dekode.Context(Context)),
) -> State(b, List(Report(Error)), dekode.Context(Context)) {
  state.do(then:, with: {
    use <- property(name, decoder)
    Ok(decoder.zero)
  })
}

pub fn default(
  name: String,
  decoder: Decoder(a),
  default: Result(a, Report(Error)),
  then: fn(a) -> State(b, e, dekode.Context(Context)),
) -> State(b, e, dekode.Context(Context)) {
  lazy_default(name, decoder, fn() { default }, then)
}

fn lazy_default(
  name: String,
  decoder: Decoder(a),
  default: fn() -> Result(a, Report(Error)),
  then: fn(a) -> State(b, e, dekode.Context(Context)),
) -> State(b, e, dekode.Context(Context)) {
  state.do(with: property(name, decoder, default), then:)
}
