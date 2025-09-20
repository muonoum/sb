import gleam/list
import sb/extra.{type Never}

pub type State(v, err, ctx) {
  State(run: fn(ctx) -> #(Result(v, err), ctx))
}

pub fn from_result(result: Result(v, err)) -> State(v, err, _) {
  case result {
    Error(err) -> fail(err)
    Ok(v) -> succeed(v)
  }
}

pub fn run(state state: State(v, err, ctx), context ctx: ctx) -> Result(v, err) {
  state.run(ctx).0
}

pub fn context(state state: State(v, err, ctx), context ctx: ctx) -> ctx {
  state.run(ctx).1
}

pub fn get() -> State(ctx, err, ctx) {
  State(fn(ctx) { #(Ok(ctx), ctx) })
}

pub fn put(context: ctx) -> State(Nil, err, ctx) {
  State(fn(_ctx) { #(Ok(Nil), context) })
}

pub fn update(mapper: fn(ctx) -> ctx) -> State(Nil, err, ctx) {
  bind(get(), fn(ctx) { put(mapper(ctx)) })
}

pub fn succeed(v: v) -> State(v, err, ctx) {
  State(fn(ctx) { #(Ok(v), ctx) })
}

pub fn fail(error: err) -> State(v, err, ctx) {
  State(fn(ctx) { #(Error(error), ctx) })
}

pub fn return(v: v) -> State(v, Never, ctx) {
  succeed(v)
}

pub fn bind(
  state: State(a, err, ctx),
  then: fn(a) -> State(b, err, ctx),
) -> State(b, err, ctx) {
  use ctx <- State
  let #(result, ctx) = state.run(ctx)

  case result {
    Ok(v) -> then(v).run(ctx)
    Error(err) -> #(Error(err), ctx)
  }
}

pub fn do(
  state: State(a, err, ctx),
  then: fn() -> State(b, err, ctx),
) -> State(b, err, ctx) {
  bind(state, fn(_) { then() })
}

pub fn map(state: State(a, err, ctx), mapper: fn(a) -> b) -> State(b, err, ctx) {
  use ctx <- State
  let #(result, ctx) = state.run(ctx)

  case result {
    Ok(v) -> #(Ok(mapper(v)), ctx)
    Error(err) -> #(Error(err), ctx)
  }
}

pub fn map2(
  state1: State(a, err, ctx),
  state2: State(b, err, ctx),
  mapper: fn(a, b) -> c,
) -> State(c, err, ctx) {
  use ctx <- State
  let #(result, ctx) = state1.run(ctx)

  case result {
    Error(error) -> #(Error(error), ctx)

    Ok(a) -> {
      let #(result, ctx) = state2.run(ctx)

      case result {
        Error(error) -> #(Error(error), ctx)
        Ok(b) -> #(Ok(mapper(a, b)), ctx)
      }
    }
  }
}

pub fn map_error(
  state: State(v, a, ctx),
  mapper: fn(a) -> b,
) -> State(v, b, ctx) {
  use ctx <- State
  let #(result, ctx) = state.run(ctx)

  case result {
    Ok(v) -> #(Ok(v), ctx)
    Error(err) -> #(Error(mapper(err)), ctx)
  }
}

pub fn replace(state: State(_, err, ctx), v: v) -> State(v, err, ctx) {
  use ctx <- State
  let #(result, ctx) = state.run(ctx)

  case result {
    Ok(_) -> #(Ok(v), ctx)
    Error(err) -> #(Error(err), ctx)
  }
}

pub fn replace_error(state: State(v, _, ctx), err: err) -> State(v, err, _) {
  use ctx <- State
  let #(result, ctx) = state.run(ctx)

  case result {
    Ok(v) -> #(Ok(v), ctx)
    Error(_) -> #(Error(err), ctx)
  }
}

pub fn attempt(
  state: State(v, err, ctx),
  catch catch: fn(ctx, err) -> State(v, err, ctx),
) -> State(v, err, ctx) {
  use ctx1 <- State
  let #(result, ctx2) = state.run(ctx1)

  case result {
    Ok(value) -> #(Ok(value), ctx2)
    Error(error) -> catch(ctx2, error).run(ctx1)
  }
}

pub fn catch_error(_ctx: ctx, err: err) -> State(Result(v, err), err, ctx) {
  succeed(Error(err))
}

pub fn sequence(states: List(State(v, err, ctx))) -> State(List(v), err, ctx) {
  let prepend = fn(list, a) { [a, ..list] }
  let callback = fn(a, list) { map2(a, list, prepend) }
  list.fold(states, succeed([]), callback)
  |> map(list.reverse)
}
