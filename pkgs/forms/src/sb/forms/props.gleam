import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/set
import sb/extra/function.{identity}
import sb/extra/report.{type Report}
import sb/extra/state.{type State}
import sb/forms/decoder.{type Decoder}
import sb/forms/error.{type Error}
import sb/forms/zero.{type Zero}

pub type Props(v) =
  State(v, Context)

pub type Context {
  Context(dict: Dict(String, Dynamic))
}

pub type Try(v) =
  Props(Result(v, Report(Error)))

pub fn error_context(error: Error) -> fn(Try(v)) -> Try(v) {
  use state <- identity
  use report <- state.map_error(state)
  report.context(report, error)
}

pub fn get_dict(then: fn(Dict(String, Dynamic)) -> Props(v)) -> Props(v) {
  use Context(dict:) <- state.bind(state.get())
  then(dict)
}

pub fn drop(keys: List(String)) -> Props(Nil) {
  use Context(dict:) <- state.update
  Context(dict: dict.drop(dict, keys))
}

pub fn merge(other: Dict(String, Dynamic)) -> Props(Nil) {
  use Context(dict:) <- state.update
  Context(dict: dict.merge(dict, other))
}

pub fn replace(dict: Dict(String, Dynamic)) -> Props(Nil) {
  use _context <- state.update
  Context(dict:)
}

pub fn decode(dynamic: Dynamic, decoder: Try(v)) -> Result(v, Report(Error)) {
  let context = Context(dict: dict.new())
  state.run(context:, state: load(dynamic, fn() { decoder }))
}

pub fn load(dynamic: Dynamic, then: fn() -> Try(v)) -> Try(v) {
  let result =
    decode.run(dynamic, decode.dict(decode.string, decode.dynamic))
    |> report.map_error(error.DecodeError)

  case result {
    Error(report) -> state.error(report)
    Ok(dict) -> state.do(state.put(Context(dict:)), then)
  }
}

pub fn check_keys(keys: List(String)) -> Props(Nil) {
  use Context(dict:) <- state.bind(state.get())

  state.from_result(known_keys(dict, keys))
  |> state.replace(Nil)
}

fn known_keys(
  dict: Dict(String, v),
  known_keys: List(String),
) -> Result(Dict(String, v), Report(Error)) {
  let defined_set = set.from_list(dict.keys(dict))
  let known_set = set.from_list(known_keys)
  let unknown_keys = set.to_list(set.difference(defined_set, known_set))
  use <- bool.guard(unknown_keys == [], Ok(dict))
  report.error(error.UnknownKeys(unknown_keys))
}

pub fn get(name: String, decoder: Decoder(a), then: fn(a) -> Try(b)) -> Try(b) {
  use dict <- get_dict

  let result = case dict.get(dict, name) {
    Error(Nil) -> report.error(error.MissingProperty(name))

    Ok(dynamic) ->
      decoder(dynamic)
      |> report.error_context(error.BadProperty(name))
  }

  case result {
    Error(report) -> state.error(report)
    Ok(value) -> then(value)
  }
}

pub fn try(name: String, zero: Zero(a), then: fn(a) -> Try(b)) -> Try(b) {
  use dict <- get_dict

  let result = case dict.get(dict, name) {
    Error(Nil) -> Ok(zero.value(zero))

    Ok(dynamic) ->
      zero.decoder(dynamic)
      |> report.error_context(error.BadProperty(name))
  }

  case result {
    Error(report) -> state.error(report)
    Ok(value) -> then(value)
  }
}
