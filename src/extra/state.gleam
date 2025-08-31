import gleam/pair

pub type State(v, e, c) {
  State(run: fn(c) -> #(c, Result(v, e)))
}

pub fn from_result(result: Result(v, e)) -> State(v, e, _) {
  case result {
    Error(error) -> fail(error)
    Ok(value) -> succeed(value)
  }
}

pub fn run(state state: State(v, e, c), context context: c) -> Result(v, e) {
  pair.second(step(state, context))
}

pub fn step(state: State(v, e, c), context: c) -> #(c, Result(v, e)) {
  state.run(context)
}

pub fn succeed(value: v) -> State(v, e, c) {
  use context <- State
  #(context, Ok(value))
}

pub fn fail(error: e) -> State(v, e, c) {
  use context <- State
  #(context, Error(error))
}

pub fn do(
  with state: State(a, e, c),
  then then: fn() -> State(b, e, c),
) -> State(b, e, c) {
  use _ <- with(state)
  then()
}

pub fn with(
  with state: State(a, e, c),
  then then: fn(a) -> State(b, e, c),
) -> State(b, e, c) {
  use context <- State
  let #(context, result) = state.run(context)

  case result {
    Ok(value) -> step(then(value), context)
    Error(error) -> #(context, Error(error))
  }
}

pub fn get() -> State(c, e, c) {
  use context <- State
  #(context, Ok(context))
}

pub fn put(context: c) -> State(Nil, e, c) {
  use _context <- State
  #(context, Ok(Nil))
}

pub fn update(mapper: fn(context) -> context) {
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

pub fn replace_error(state: State(_, _, _), error: e) -> State(_, e, _) {
  use context <- State
  let #(context, result) = state.run(context)

  case result {
    Ok(value) -> #(context, value)
    Error(_error) -> #(context, Error(error))
  }
}

pub fn attempt(
  state: State(v, e, c),
  catch catch: fn(c, e) -> State(v, e, c),
) -> State(v, e, c) {
  use context1 <- State
  let #(context2, result) = state.run(context1)

  case result {
    Ok(value) -> #(context2, Ok(value))
    Error(error) -> step(catch(context2, error), context1)
  }
}
