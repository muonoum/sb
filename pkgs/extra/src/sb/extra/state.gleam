import gleam/list
import sb/extra/function

pub type State(v, ctx) {
  State(run: fn(ctx) -> #(v, ctx))
}

pub fn run(state state: State(v, ctx), context ctx: ctx) -> v {
  state.run(ctx).0
}

pub fn get() -> State(ctx, ctx) {
  State(fn(ctx) { #(ctx, ctx) })
}

pub fn put(ctx: ctx) -> State(Nil, ctx) {
  State(fn(_ctx) { #(Nil, ctx) })
}

pub fn update(mapper: fn(ctx) -> ctx) -> State(Nil, ctx) {
  bind(get(), fn(ctx) { put(mapper(ctx)) })
}

pub fn return(v: v) -> State(v, ctx) {
  State(fn(ctx) { #(v, ctx) })
}

pub fn bind(state: State(a, ctx), then: fn(a) -> State(b, ctx)) -> State(b, ctx) {
  use ctx <- State
  let #(v, ctx) = state.run(ctx)
  then(v).run(ctx)
}

pub fn do(state: State(a, ctx), then: fn() -> State(b, ctx)) -> State(b, ctx) {
  bind(state, fn(_) { then() })
}

pub fn replace(state: State(_, ctx), v: v) -> State(v, ctx) {
  use ctx <- State
  let #(_, context) = state.run(ctx)
  #(v, context)
}

pub fn map(state: State(a, ctx), mapper: fn(a) -> b) -> State(b, ctx) {
  use ctx <- State
  let #(v, ctx) = state.run(ctx)
  #(mapper(v), ctx)
}

pub fn map2(
  state1: State(a, ctx),
  state2: State(b, ctx),
  mapper: fn(a, b) -> c,
) -> State(c, ctx) {
  use ctx <- State
  let #(a, ctx) = state1.run(ctx)
  let #(b, ctx) = state2.run(ctx)
  #(mapper(a, b), ctx)
}

pub fn sequence(states: List(State(v, ctx))) -> State(List(v), ctx) {
  use <- function.return(map(_, list.reverse))
  use list, state <- list.fold(states, return([]))
  map2(list, state, list.prepend)
}

// Result

pub fn from_result(r: Result(v, err)) -> State(Result(v, err), ctx) {
  return(r)
}

pub fn succeed(v: v) -> State(Result(v, err), ctx) {
  return(Ok(v))
}

pub fn fail(err: err) -> State(Result(v, err), ctx) {
  return(Error(err))
}

pub fn try(
  with state: State(Result(a, err), ctx),
  then then: fn(a) -> State(Result(b, err), ctx),
) -> State(Result(b, err), ctx) {
  use ctx <- State
  let #(result, ctx) = state.run(ctx)

  case result {
    Ok(v) -> then(v).run(ctx)
    Error(err) -> #(Error(err), ctx)
  }
}

pub fn map_error(
  state: State(Result(_, a), ctx),
  mapper: fn(a) -> b,
) -> State(Result(_, b), ctx) {
  use ctx <- State
  let #(result, ctx) = state.run(ctx)

  case result {
    Ok(v) -> #(Ok(v), ctx)
    Error(err) -> #(Error(mapper(err)), ctx)
  }
}
