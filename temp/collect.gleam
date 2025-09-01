import extra/state.{type State}
import gleam/bool
import gleam/list
import sb/error.{type Error}
import sb/report.{type Report}

fn collect(reports: List(Report(Error))) -> Report(Error) {
  report.new(error.Collected(list.reverse(reports)))
}

pub fn run(state: fn() -> State(v, e, List(Report(Error)))) -> Result(v, e) {
  state.run(state(), [])
}

pub fn succeed(value: v) -> State(v, Report(Error), List(Report(Error))) {
  use reports <- state.do(state.get())
  use <- bool.guard(reports == [], state.succeed(value))
  state.fail(collect(reports))
}

pub fn require(
  result: Result(a, Report(Error)),
  then: fn(a) -> State(b, Report(Error), List(Report(Error))),
) -> State(b, Report(Error), List(Report(Error))) {
  state.do(then:, with: {
    use reports <- state.do(state.get())

    case result {
      Error(report) -> state.fail(collect([report, ..reports]))
      Ok(value) -> state.succeed(value)
    }
  })
}

pub fn try(
  zero zero: a,
  value result: Result(a, Report(Error)),
  then then: fn(a) -> State(b, Report(Error), List(Report(Error))),
) -> State(b, Report(Error), List(Report(Error))) {
  state.do(then:, with: {
    use reports <- state.do(state.get())

    case result {
      Ok(value) -> state.succeed(value)

      Error(report) -> {
        let context = state.put([report, ..reports])
        use _value <- state.do(context)
        state.succeed(zero)
      }
    }
  })
}
