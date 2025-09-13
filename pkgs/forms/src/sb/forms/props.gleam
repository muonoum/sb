import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import sb/extra/report.{type Report}
import sb/extra/state_eval.{type State} as state
import sb/forms/decoder.{type Decoder}
import sb/forms/error.{type Error}
import sb/forms/zero.{type Zero}

pub type Context {
  Context(dict: Dict(String, Dynamic), reports: List(Report(Error)))
}

pub type Props(v) =
  State(v, Report(Error), Context)

pub fn succeed(value: v) -> Props(v) {
  state.succeed(value)
}

pub fn fail(error: Report(Error)) -> Props(v) {
  state.fail(error)
}

pub fn error_context(error: Error) -> fn(Props(v)) -> Props(v) {
  fn(result) {
    use report <- state.map_error(result)
    report.context(report, error)
  }
}

pub fn get_dict(then: fn(Dict(String, Dynamic)) -> Props(v)) -> Props(v) {
  use Context(dict:, ..) <- state.bind(state.get())
  then(dict)
}

pub fn drop(keys: List(String)) -> Props(Nil) {
  use Context(dict:, reports:) <- state.update
  Context(dict: dict.drop(dict, keys), reports:)
}

pub fn merge(other: Dict(String, Dynamic)) -> Props(Nil) {
  use Context(dict:, reports:) <- state.update
  Context(dict: dict.merge(dict, other), reports:)
}

pub fn get_reports(then: fn(List(Report(Error))) -> Props(v)) -> Props(v) {
  use Context(reports:, ..) <- state.bind(state.get())
  then(list.reverse(reports))
}

pub fn add_report(report: Report(Error)) -> Props(Nil) {
  use Context(dict:, reports:) <- state.update
  Context(dict:, reports: [report, ..reports])
}

pub fn replace(dict: Dict(String, Dynamic)) -> Props(Nil) {
  use context <- state.update
  Context(..context, dict:)
}

pub fn decode(dynamic: Dynamic, decoder: Props(v)) -> Result(v, Report(Error)) {
  let context = Context(dict: dict.new(), reports: [])

  state.run(context:, state: {
    use <- load(dynamic)
    decoder
  })
}

pub fn check_keys(keys: List(String)) -> Props(Nil) {
  use Context(dict:, ..) <- state.bind(state.get())

  state.from_result(error.unknown_keys(dict, keys))
  |> state.replace(Nil)
}

pub fn load(dynamic: Dynamic, next: fn() -> Props(v)) -> Props(v) {
  let result =
    decode.run(dynamic, decode.dict(decode.string, decode.dynamic))
    |> report.map_error(error.DecodeError)

  case result {
    Error(report) -> state.fail(report)

    Ok(dict) -> {
      use context <- state.bind(state.get())
      state.do(state.put(Context(..context, dict:)), next)
    }
  }
}

pub fn get(
  name: String,
  decoder: Decoder(a),
  then: fn(a) -> Props(b),
) -> Props(b) {
  use dict <- get_dict

  let result = case dict.get(dict, name) {
    Error(Nil) -> report.error(error.MissingProperty(name))

    Ok(dynamic) ->
      decoder(dynamic)
      |> report.error_context(error.BadProperty(name))
  }

  case result {
    Error(report) -> state.fail(report)
    Ok(value) -> then(value)
  }
}

pub fn try(name: String, zero: Zero(a), then: fn(a) -> Props(b)) -> Props(b) {
  use dict <- get_dict

  let result = case dict.get(dict, name) {
    Error(Nil) -> Ok(zero.value(zero))

    Ok(dynamic) ->
      zero.decoder(dynamic)
      |> report.error_context(error.BadProperty(name))
  }

  case result {
    Error(report) -> state.fail(report)
    Ok(value) -> then(value)
  }
}
