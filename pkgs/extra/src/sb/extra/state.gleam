import gleam/list
import sb/extra/function

pub type State(v, ctx) {
  State(run: fn(ctx) -> #(v, ctx))
}

pub fn step(state state: State(v, ctx), context context: ctx) -> #(v, ctx) {
  state.run(context)
}

pub fn run(state state: State(v, ctx), context context: ctx) -> v {
  step(state:, context:).0
}

pub fn return(value: v) -> State(v, ctx) {
  use context <- State
  #(value, context)
}

pub fn bind(
  with state: State(a, ctx),
  then then: fn(a) -> State(b, ctx),
) -> State(b, ctx) {
  use context <- State
  let #(value, context) = state.run(context)
  step(state: then(value), context:)
}

pub fn do(
  with state: State(a, ctx),
  then then: fn() -> State(b, ctx),
) -> State(b, ctx) {
  bind(state, fn(_) { then() })
}

pub fn get() -> State(ctx, ctx) {
  use context <- State
  #(context, context)
}

pub fn put(context: ctx) -> State(Nil, ctx) {
  use _context <- State
  #(Nil, context)
}

pub fn update(mapper: fn(ctx) -> ctx) -> State(Nil, ctx) {
  use context <- bind(get())
  put(mapper(context))
}

pub fn replace(state: State(_, ctx), value: v) -> State(v, ctx) {
  use context <- State
  let #(_, context) = state.run(context)
  #(value, context)
}

pub fn map(state: State(a, ctx), mapper: fn(a) -> b) -> State(b, ctx) {
  use context <- State
  let #(value, context) = state.run(context)
  #(mapper(value), context)
}

pub fn map2(
  state1: State(a, ctx),
  state2: State(b, ctx),
  mapper: fn(a, b) -> c,
) -> State(c, ctx) {
  use context <- State
  let #(a, context) = state1.run(context)
  let #(b, context) = state2.run(context)
  #(mapper(a, b), context)
}

pub fn sequence(states: List(State(v, ctx))) -> State(List(v), ctx) {
  use <- function.return(map(_, list.reverse))
  use list, state <- list.fold(states, return([]))
  map2(list, state, list.prepend)
}

// Result

pub fn from_result(result: Result(v, err)) -> State(Result(v, err), ctx) {
  return(result)
}

pub fn succeed(value: v) -> State(Result(v, err), ctx) {
  return(Ok(value))
}

pub fn fail(error: err) -> State(Result(v, err), ctx) {
  return(Error(error))
}

pub fn try(
  with state: State(Result(a, err), ctx),
  then then: fn(a) -> State(Result(b, err), ctx),
) -> State(Result(b, err), ctx) {
  use context <- State
  let #(result, context) = state.run(context)

  case result {
    Ok(value) -> step(state: then(value), context:)
    Error(error) -> #(Error(error), context)
  }
}

pub fn map_error(
  state: State(Result(_, a), ctx),
  mapper: fn(a) -> b,
) -> State(Result(_, b), ctx) {
  use context <- State
  let #(result, context) = state.run(context)

  case result {
    Ok(value) -> #(Ok(value), context)
    Error(error) -> #(Error(mapper(error)), context)
  }
}
