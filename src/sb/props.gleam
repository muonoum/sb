import extra/state
import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import sb/error.{type Error}
import sb/report.{type Report}

pub type Decoder(v) {
  Decoder(zero: v, decode: fn(Dynamic) -> Result(v, Report(Error)))
}

pub fn run_decoder(
  dynamic: Dynamic,
  decoder: decode.Decoder(v),
) -> Result(v, Report(Error)) {
  decode.run(dynamic, decoder)
  |> report.map_error(error.DecodeError)
}

pub fn string() -> Decoder(String) {
  Decoder(zero: "", decode: run_decoder(_, decode.string))
}

pub fn list(inner: Decoder(v)) -> Decoder(List(v)) {
  Decoder(zero: [], decode: fn(dynamic) {
    run_decoder(dynamic, decode.list(decode.dynamic))
    |> result.try(list.try_map(_, inner.decode))
  })
}

pub fn optional(inner: Decoder(v)) -> Decoder(Option(v)) {
  Decoder(zero: None, decode: fn(dynamic) {
    use value <- result.try({
      run_decoder(dynamic, decode.optional(decode.dynamic))
    })

    case option.map(value, inner.decode) {
      Some(Error(report)) -> Error(report)
      Some(Ok(value)) -> Ok(Some(value))
      None -> Ok(None)
    }
  })
}

type State(v) =
  state.State(v, List(Report(Error)), Context)

pub type Context {
  Context(Dict(String, Dynamic), reports: List(Report(Error)))
}

pub fn succeed(value: v) -> State(v) {
  use Context(_, reports) <- state.with(state.get())
  use <- bool.guard(reports == [], state.succeed(value))
  state.fail(list.reverse(reports))
}

pub fn fail(report: Report(Error)) -> State(_) {
  use Context(_, reports) <- state.with(state.get())
  state.fail(list.reverse([report, ..reports]))
}

pub fn decode(
  dynamic: Dynamic,
  keys: List(String),
  decoder: State(v),
) -> Result(v, _) {
  Context(dict.new(), reports: [])
  |> state.run(context: _, state: {
    use <- load(dynamic, keys)
    decoder
  })
}

fn load(
  dynamic: Dynamic,
  keys: List(String),
  next: fn() -> State(v),
) -> State(v) {
  let result = run_decoder(dynamic, decode.dict(decode.string, decode.dynamic))

  case result {
    Error(report) -> fail(report)

    Ok(dict) -> {
      use Context(_, reports) <- state.with(state.get())

      let context = case error.unknown_keys(dict, keys) {
        Error(report) -> Context(dict, reports: [report, ..reports])
        Ok(dict) -> Context(dict, reports:)
      }

      state.put(context)
      |> state.do(next)
    }
  }
}

fn property(
  key: String,
  decoder: Decoder(v),
  default: fn() -> Result(v, _),
) -> State(v) {
  use Context(dict, ..) <- state.with(state.get())

  let result = case dict.get(dict, key) {
    Error(Nil) -> default()

    Ok(dynamic) ->
      decoder.decode(dynamic)
      |> report.error_context(error.BadProperty(key))
  }

  case result {
    Ok(value) -> state.succeed(value)

    Error(report) -> {
      use Context(dict, reports) <- state.with(state.get())
      let ctx = Context(dict, reports: [report, ..reports])
      use <- state.do(state.put(ctx))
      state.succeed(decoder.zero)
    }
  }
}

pub fn required(
  name: String,
  decoder: Decoder(a),
  then: fn(a) -> State(b),
) -> State(b) {
  state.with(then:, with: {
    use <- property(name, decoder)
    report.error(error.MissingProperty(name))
  })
}

pub fn zero(
  name: String,
  decoder: Decoder(a),
  then: fn(a) -> State(v),
) -> State(v) {
  state.with(then:, with: {
    use <- property(name, decoder)
    Ok(decoder.zero)
  })
}

pub fn default(
  name: String,
  decoder: Decoder(a),
  default: Result(a, _),
  then: fn(a) -> State(v),
) -> State(v) {
  state.with(then:, with: {
    use <- property(name, decoder)
    default
  })
}

pub fn lazy_default(
  name: String,
  decoder: Decoder(a),
  default: fn() -> Result(a, _),
  then: fn(a) -> State(v),
) -> State(v) {
  state.with(then:, with: {
    use <- property(name, decoder)
    default()
  })
}
