import extra/state.{type State}
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{None, Some}
import gleam/pair
import sb/error.{type Error}
import sb/report.{type Report}
import sb/zero.{type Zero}

pub opaque type Context {
  Context(dict: Dict(String, Dynamic), reports: List(Report(Error)))
}

pub type Props(v) =
  State(v, Report(Error), Context)

pub fn get(then: fn(Dict(String, Dynamic)) -> Props(v)) -> Props(v) {
  use Context(dict:, ..) <- state.with(state.get())
  then(dict)
}

pub fn merge(other: Dict(String, Dynamic)) -> Props(Nil) {
  use Context(dict:, reports:) <- state.update()
  Context(dict: dict.merge(dict, other), reports:)
}

pub fn get_reports(then: fn(List(Report(Error))) -> Props(v)) -> Props(v) {
  use Context(reports:, ..) <- state.with(state.get())
  then(list.reverse(reports))
}

pub fn add_report(report: Report(Error)) -> Props(Nil) {
  use Context(dict:, reports:) <- state.update()
  Context(dict:, reports: [report, ..reports])
}

// TODO: List(Report(Error))
// TODO: fail -> report + reports fra context
pub fn decode(dynamic: Dynamic, decoder: Props(v)) -> Result(v, Report(Error)) {
  let context = Context(dict: dict.new(), reports: [])

  state.run(context:, state: {
    use <- load(dynamic)
    use value <- state.with(decoder)
    use reports <- get_reports()

    case reports {
      [] -> state.succeed(value)
      reports -> state.fail(report.new(error.Collected(list.reverse(reports))))
    }
  })
}

pub fn check_keys(keys: List(String)) -> Props(Nil) {
  use Context(dict:, ..) <- state.with(state.get())

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
      use context <- state.with(state.get())
      state.do(state.put(Context(..context, dict:)), next)
    }
  }
}

pub fn required(
  name: String,
  decoder: fn(Dynamic) -> Zero(a),
  then: fn(a) -> Props(b),
) -> Props(b) {
  state.with(then:, with: {
    use zero <- property(name, decoder)
    #(zero, Some(report.new(error.MissingProperty(name))))
  })
}

pub fn zero(
  name: String,
  decoder: fn(Dynamic) -> Zero(a),
  then: fn(a) -> Props(b),
) -> Props(b) {
  state.with(then:, with: {
    use zero <- property(name, decoder)
    #(zero, None)
  })
}

pub fn default(
  name: String,
  default: Result(a, Report(Error)),
  decoder: fn(Dynamic) -> Zero(a),
  then: fn(a) -> Props(b),
) -> Props(b) {
  state.with(then:, with: {
    use zero <- property(name, decoder)

    case default {
      Error(report) -> #(zero, Some(report))
      Ok(value) -> #(value, None)
    }
  })
}

pub fn property(
  name: String,
  decoder: fn(Dynamic) -> Zero(v),
  zero: fn(v) -> Zero(v),
) -> Props(v) {
  use dict <- get()

  let result = case dict.get(dict, name) {
    Error(Nil) -> zero(pair.first(decoder(dynamic.nil())))

    Ok(dynamic) -> {
      use report <- pair.map_second(decoder(dynamic))
      option.map(report, report.context(_, error.BadProperty(name)))
    }
  }

  case result {
    #(value, None) -> state.succeed(value)

    #(value, Some(report)) -> {
      use <- state.do(add_report(report))
      state.succeed(value)
    }
  }
}
