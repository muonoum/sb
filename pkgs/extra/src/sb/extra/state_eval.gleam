import gleam/list

pub type State(v, err, ctx) {
  State(run: fn(ctx) -> #(ctx, Result(v, err)))
}

pub fn from_result(result: Result(v, err)) -> State(v, err, _) {
  case result {
    Error(error) -> fail(error)
    Ok(value) -> succeed(value)
  }
}

pub fn run(
  state state: State(v, err, ctx),
  context context: ctx,
) -> Result(v, err) {
  step(state, context).1
}

pub fn context(state state: State(v, err, ctx), context context: ctx) -> ctx {
  step(state, context).0
}

pub fn step(state: State(v, err, ctx), context: ctx) -> #(ctx, Result(v, err)) {
  state.run(context)
}

pub fn succeed(value: v) -> State(v, err, ctx) {
  use context <- State
  #(context, Ok(value))
}

pub fn fail(error: err) -> State(v, err, ctx) {
  use context <- State
  #(context, Error(error))
}

pub fn do(
  with state: State(a, err, ctx),
  then then: fn() -> State(b, err, ctx),
) -> State(b, err, ctx) {
  use _ <- with(state)
  then()
}

pub fn with(
  with state: State(a, err, ctx),
  then then: fn(a) -> State(b, err, ctx),
) -> State(b, err, ctx) {
  use context <- State
  let #(context, result) = state.run(context)

  case result {
    Ok(value) -> step(then(value), context)
    Error(error) -> #(context, Error(error))
  }
}

pub fn get() -> State(ctx, err, ctx) {
  use context <- State
  #(context, Ok(context))
}

pub fn put(context: ctx) -> State(Nil, err, ctx) {
  use _context <- State
  #(context, Ok(Nil))
}

pub fn update(mapper: fn(ctx) -> ctx) {
  use context <- with(get())
  put(mapper(context))
}

pub fn map(state: State(a, _, _), mapper: fn(a) -> b) -> State(b, _, _) {
  use context <- State
  let #(context, result) = state.run(context)

  case result {
    Ok(value) -> #(context, Ok(mapper(value)))
    Error(error) -> #(context, Error(error))
  }
}

pub fn map2(
  state1: State(a, _, _),
  state2: State(b, _, _),
  mapper: fn(a, b) -> c,
) -> State(c, _, _) {
  use context <- State
  let #(context, result) = state1.run(context)

  case result {
    Error(error) -> #(context, Error(error))

    Ok(a) -> {
      let #(context, result) = state2.run(context)

      case result {
        Error(error) -> #(context, Error(error))
        Ok(b) -> #(context, Ok(mapper(a, b)))
      }
    }
  }
}

pub fn map_error(state: State(_, a, _), mapper: fn(a) -> b) -> State(_, b, _) {
  use context <- State
  let #(context, result) = state.run(context)

  case result {
    Ok(value) -> #(context, Ok(value))
    Error(error) -> #(context, Error(mapper(error)))
  }
}

pub fn try(
  state: State(a, _, _),
  mapper: fn(a) -> State(b, _, _),
) -> State(b, _, _) {
  use context <- State
  let #(context, result) = state.run(context)

  case result {
    Ok(value) -> step(mapper(value), context)
    Error(error) -> #(context, Error(error))
  }
}

pub fn replace(state: State(_, _, _), value: v) -> State(v, _, _) {
  use context <- State
  let #(context, result) = state.run(context)

  case result {
    Ok(_value) -> #(context, Ok(value))
    Error(error) -> #(context, Error(error))
  }
}

pub fn replace_error(state: State(_, _, _), error: err) -> State(_, err, _) {
  use context <- State
  let #(context, result) = state.run(context)

  case result {
    Ok(value) -> #(context, value)
    Error(_error) -> #(context, Error(error))
  }
}

pub fn attempt(
  state: State(_, err, ctx),
  catch catch: fn(ctx, err) -> State(_, err, ctx),
) -> State(_, err, ctx) {
  use context1 <- State
  let #(context2, result) = state.run(context1)

  case result {
    Ok(value) -> #(context2, Ok(value))
    Error(error) -> step(catch(context2, error), context1)
  }
}

pub fn catch_error(_ctx: _, error: err) -> State(Result(_, err), err, _) {
  succeed(Error(error))
}

pub fn sequence(states: List(State(v, _, _))) -> State(List(v), _, _) {
  let prepend = fn(list, a) { [a, ..list] }
  let callback = fn(a, list) { map2(a, list, prepend) }
  list.fold(states, succeed([]), callback)
  |> map(list.reverse)
}
