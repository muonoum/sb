import extra/state.{type State}
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/result
import sb/error.{type Error}
import sb/report.{type Report}
import sb/reports

// DECODE

pub type Decoder(v) {
  Decoder(zero: fn() -> v, decode: fn(Dynamic) -> Result(v, Report(Error)))
}

pub const string_decoder = Decoder(zero: zero_string, decode: decode_string)

pub fn zero_string() {
  ""
}

pub fn decode_string(dynamic: Dynamic) -> Result(String, Report(Error)) {
  decode.run(dynamic, decode.string)
  |> report.map_error(error.DecodeError)
}

// MAIN

pub fn main() {
  let keys = []

  let decoder = {
    use foo <- props_required("foo", string_decoder)
    reports.succeed(foo)
  }

  echo dynamic.properties([#(dynamic.string("foo"), dynamic.string("bar"))])
    |> decode_props(keys, decoder)
}

// PROPS

pub type PropsContext =
  Dict(String, Dynamic)

pub fn decode_props(
  dynamic: Dynamic,
  keys: List(List(String)),
  decoder: State(v, _, _),
) -> Result(v, _) {
  reports.Context(dict.new(), reports: [])
  |> state.run(context: _, state: {
    use <- load_props(dynamic, keys)
    decoder
  })
}

pub fn load_props(
  dynamic: Dynamic,
  keys: List(List(String)),
  then: fn() -> State(v, _, _),
) -> State(v, _, _) {
  let result =
    decode.run(dynamic, decode.dict(decode.string, decode.dynamic))
    |> report.map_error(error.DecodeError)
    |> result.try(error.unknown_keys(_, keys))

  case result {
    Error(report) -> reports.fail(report)
    Ok(ctx) -> reports.put_context(ctx, then)
  }
}

pub fn props_prop(
  key: String,
  decoder: Decoder(v),
  default: fn() -> Result(v, _),
) -> State(v, _, _) {
  use dict <- reports.get_context()
  let Decoder(zero:, decode:) = decoder

  let result = case dict.get(dict, key) {
    Error(Nil) -> default()

    Ok(dynamic) ->
      decode(dynamic)
      |> report.error_context(error.BadProperty(key))
  }

  case result {
    Ok(value) -> state.succeed(value)

    Error(report) -> {
      use <- reports.report(report)
      state.succeed(zero())
    }
  }
}

fn props_required(name, decoder, then) {
  state.with(then:, with: {
    use <- props_prop(name, decoder)
    report.error(error.MissingProperty(name))
  })
}

fn props_zero(name, decoder, then) {
  state.with(then:, with: {
    use <- props_prop(name, decoder)
    Ok(decoder.zero())
  })
}

fn props_lazy_default(name, decoder, default, then) {
  state.with(then:, with: {
    use <- props_prop(name, decoder)
    Ok(default())
  })
}

fn props_default(name, decoder, default, then) {
  props_lazy_default(name, decoder, fn() { default }, then)
}
