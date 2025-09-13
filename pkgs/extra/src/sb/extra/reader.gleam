import gleam/list
import sb/extra/function.{identity}

pub opaque type Reader(v, ctx) {
  Reader(run: fn(ctx) -> v)
}

pub fn run(reader reader: Reader(v, ctx), context context: ctx) -> v {
  reader.run(context)
}

pub const ask = Reader(identity)

pub fn return(value: v) -> Reader(v, ctx) {
  use _ <- Reader
  value
}

pub fn bind(
  reader: Reader(a, ctx),
  then: fn(a) -> Reader(b, ctx),
) -> Reader(b, ctx) {
  use context <- Reader
  then(reader.run(context)).run(context)
}

pub fn do(
  with reader: Reader(a, ctx),
  then then: fn() -> Reader(b, ctx),
) -> Reader(b, ctx) {
  bind(reader, fn(_) { then() })
}

pub fn map(state: Reader(a, ctx), mapper: fn(a) -> b) -> Reader(b, ctx) {
  use context <- Reader
  let value = state.run(context)
  mapper(value)
}

pub fn map2(
  state1: Reader(a, ctx),
  state2: Reader(b, ctx),
  mapper: fn(a, b) -> c,
) -> Reader(c, ctx) {
  use context <- Reader
  mapper(state1.run(context), state2.run(context))
}

pub fn sequence(states: List(Reader(v, ctx))) -> Reader(List(v), ctx) {
  use <- function.return(map(_, list.reverse))
  use list, state <- list.fold(states, return([]))
  map2(list, state, list.prepend)
}
