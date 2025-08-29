import extra
import extra/state.{type State}
import gleam/bool
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pair
import gleam/result
import gleam/set
import sb/error.{type Error}
import sb/report.{type Report}

pub type Context(ctx) {
  Context(ctx, reports: List(Report(Error)))
}

pub type Decoder(v) {
  Decoder(zero: v, decoder: fn(Dynamic) -> Result(v, Report(Error)))
}

fn run_decoder(
  dynamic: Dynamic,
  decoder: decode.Decoder(v),
) -> Result(v, Report(Error)) {
  decode.run(dynamic, decoder)
  |> report.map_error(error.DecodeError)
}

pub fn std_decoder(
  decoder: decode.Decoder(v),
) -> fn(Dynamic) -> Result(v, Report(Error)) {
  run_decoder(_, decoder)
}

pub fn string() -> Decoder(String) {
  Decoder(zero: "", decoder: std_decoder(decode.string))
}

pub fn list(inner: decode.Decoder(v)) -> Decoder(List(v)) {
  Decoder(zero: [], decoder: std_decoder(decode.list(inner)))
}

pub fn optional(inner: decode.Decoder(v)) -> Decoder(Option(v)) {
  Decoder(zero: None, decoder: std_decoder(decode.map(inner, Some)))
}

pub fn pairs(
  decoder: fn(Dynamic) -> Result(#(String, v), Report(Error)),
) -> Decoder(List(Result(#(String, v), Report(Error)))) {
  Decoder(zero: [], decoder: fn(dynamic) {
    use list <- result.map(run_decoder(dynamic, decode.list(decode.dynamic)))
    use <- extra.return(pair.second)
    use seen, dynamic <- list.map_fold(list, set.new())
    error.try_duplicate_ids(decoder(dynamic), seen)
  })
}

pub fn put(
  ctx: ctx,
  then: fn() -> State(v, e, Context(ctx)),
) -> State(v, e, Context(ctx)) {
  use Context(_, reports) <- state.do(state.get())
  use <- state.then(state.put(Context(ctx, reports:)))
  then()
}

pub fn get(
  then: fn(ctx) -> State(v, e, Context(ctx)),
) -> State(v, e, Context(ctx)) {
  use Context(ctx, ..) <- state.do(state.get())
  then(ctx)
}

pub fn report(
  report: Report(Error),
  then: fn() -> State(v, e, Context(ctx)),
) -> State(v, e, Context(ctx)) {
  use Context(ctx, reports) <- state.do(state.get())
  let reports = [report, ..reports]
  let context = Context(ctx, reports:)
  use <- state.then(state.put(context))
  then()
}

pub fn succeed(value: v) -> State(v, List(Report(Error)), Context(ctx)) {
  use Context(_, reports) <- state.do(state.get())
  use <- bool.guard(reports == [], state.succeed(value))
  state.fail(list.reverse(reports))
}

pub fn required(
  result: Result(a, Report(Error)),
  then: fn(a) -> State(b, List(report.Report(Error)), Context(ctx)),
) -> State(b, List(Report(Error)), Context(ctx)) {
  state.do(then:, with: {
    case result {
      Ok(value) -> state.succeed(value)

      Error(report) -> {
        use Context(_, reports) <- state.do(state.get())
        state.fail(list.reverse([report, ..reports]))
      }
    }
  })
}
