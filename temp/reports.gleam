import extra/state.{type State}
import gleam/bool
import gleam/list
import sb/error.{type Error}
import sb/report.{type Report}

pub type Context(ctx) {
  Context(ctx, reports: List(Report(Error)))
}

pub fn report(
  report: Report(Error),
  then: fn() -> State(_, List(error), Context(ctx)),
) -> State(_, List(error), Context(ctx)) {
  use Context(ctx, reports) <- state.with(state.get())
  let ctx = Context(ctx, reports: [report, ..reports])
  use <- state.do(state.put(ctx))
  then()
}

pub fn get_context(
  then: fn(ctx) -> State(_, _, Context(ctx)),
) -> State(_, _, Context(ctx)) {
  use Context(ctx, ..) <- state.with(state.get())
  then(ctx)
}

pub fn put_context(
  ctx: ctx,
  then: fn() -> State(_, _, Context(ctx)),
) -> State(_, _, Context(ctx)) {
  use Context(_, reports) <- state.with(state.get())
  use <- state.do(state.put(Context(ctx, reports:)))
  then()
}

pub fn fail(report: Report(Error)) -> State(_, List(Report(Error)), Context(_)) {
  use Context(_, reports) <- state.with(state.get())
  state.fail(list.reverse([report, ..reports]))
}

pub fn succeed(value: v) -> State(v, List(Report(Error)), Context(_)) {
  use Context(_, reports) <- state.with(state.get())
  use <- bool.guard(reports == [], state.succeed(value))
  state.fail(list.reverse(reports))
}
