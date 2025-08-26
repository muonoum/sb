import gleam/bool
import gleam/list
import sb/error.{type Error}
import sb/report.{type Report}
import sb/state.{type State}

pub fn run(state: fn() -> State(v, e, List(Report(Error)))) -> Result(v, e) {
  state.run(state(), [])
}

pub fn require(
  value: Result(a, Report(Error)),
  then: fn(a) -> State(b, Report(Error), List(Report(Error))),
) -> State(b, Report(Error), List(Report(Error))) {
  state.try(do_require(value), then)
}

fn do_require(result: Result(a, Report(Error))) -> State(a, Report(Error), c) {
  use _context <- state.try(state.get())

  case result {
    Error(report) -> state.fail(report)
    Ok(value) -> state.succeed(value)
  }
}

pub fn try(
  zero zero: a,
  value result: Result(a, Report(Error)),
  then then: fn(a) -> State(b, Report(Error), List(Report(Error))),
) -> State(b, Report(Error), List(Report(Error))) {
  state.try(do_try(zero, result), then)
}

fn do_try(
  zero: v,
  result: Result(v, Report(Error)),
) -> State(v, Report(Error), List(Report(Error))) {
  use reports <- state.try(state.get())

  case result {
    Ok(value) -> state.succeed(value)

    Error(report) -> {
      let context = state.set([report, ..reports])
      use _value <- state.try(context)
      state.succeed(zero)
    }
  }
}

pub fn succeed(value: v) -> State(v, Report(Error), List(Report(Error))) {
  use reports <- state.try(state.get())
  use <- bool.guard(reports == [], state.succeed(value))

  state.fail(report.new(
    list.reverse(list.unique(reports))
    |> error.Errors,
  ))
}
