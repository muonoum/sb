import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/result
import gleam/set
import sb/extra/function.{compose, identity, return}
import sb/extra/report.{type Report}
import sb/extra/state.{type State}
import sb/forms/decoder.{type Decoder}
import sb/forms/error.{type Error}
import sb/forms/zero.{type Zero}

pub type Props(v) =
  State(v, Context)

pub type Try(v) =
  Props(Result(v, Report(Error)))

pub type Context {
  Context(dict: Dict(String, Dynamic))
}

// TODO?
// pub type Context {
//   Context(dict: Dict(String, Dynamic), reports: List(Report))
// }

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
  decode_dict(dict.new(), load(dynamic, decoder))
}

pub fn decode_dict(
  dict: Dict(String, Dynamic),
  decoder: Try(v),
) -> Result(v, Report(Error)) {
  state.run(context: Context(dict:), state: decoder)
}

pub fn load(dynamic: Dynamic, decoder: Try(v)) -> Try(v) {
  let result =
    decode.run(dynamic, decode.dict(decode.string, decode.dynamic))
    |> report.map_error(error.DecodeError)

  case result {
    Error(report) -> state.error(report)

    Ok(dict) -> {
      use <- state.do(state.put(Context(dict:)))
      decoder
    }
  }
}

pub fn check_keys(known_keys: List(String)) -> Try(Nil) {
  use Context(dict:) <- state.bind(state.get())
  use <- return(compose(result.replace(_, Nil), state.from_result))
  let defined_set = set.from_list(dict.keys(dict))
  let known_set = set.from_list(known_keys)
  let unknown_keys = set.to_list(set.difference(defined_set, known_set))
  use <- bool.guard(unknown_keys == [], Ok(dict))
  report.error(error.UnknownKeys(unknown_keys))
}

pub fn error_context(error: Error) -> fn(Try(v)) -> Try(v) {
  use state <- identity
  use report <- state.map_error(state)
  report.context(report, error)
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

pub fn try(name: String, zero: Zero(a, Nil), then: fn(a) -> Try(b)) -> Try(b) {
  use dict <- get_dict

  let result = case dict.get(dict, name) {
    Error(Nil) ->
      // TODO
      case zero.value(zero) {
        Error(Nil) -> report.error(error.MissingProperty(name))
        Ok(value) -> Ok(value)
      }

    Ok(dynamic) ->
      zero.decoder(dynamic)
      |> report.error_context(error.BadProperty(name))
  }

  case result {
    Error(report) -> state.error(report)
    Ok(value) -> then(value)
  }
}
