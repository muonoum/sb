import gleam/list
import sb/extra/function.{identity}

pub opaque type Reader(v, ctx) {
  Reader(run: fn(ctx) -> v)
}

pub fn run(reader reader: Reader(v, ctx), context ctx: ctx) -> v {
  reader.run(ctx)
}

pub const ask = Reader(identity)

pub fn return(value: v) -> Reader(v, ctx) {
  Reader(fn(_) { value })
}

pub fn bind(
  reader: Reader(a, ctx),
  then: fn(a) -> Reader(b, ctx),
) -> Reader(b, ctx) {
  use ctx <- Reader
  then(reader.run(ctx)).run(ctx)
}

pub fn do(
  with reader: Reader(a, ctx),
  then then: fn() -> Reader(b, ctx),
) -> Reader(b, ctx) {
  bind(reader, fn(_) { then() })
}

pub fn map(reader: Reader(a, ctx), mapper: fn(a) -> b) -> Reader(b, ctx) {
  use ctx <- Reader
  mapper(reader.run(ctx))
}

pub fn map2(
  reader1: Reader(a, ctx),
  reader2: Reader(b, ctx),
  mapper: fn(a, b) -> c,
) -> Reader(c, ctx) {
  use ctx <- Reader
  mapper(reader1.run(ctx), reader2.run(ctx))
}

pub fn sequence(readers: List(Reader(v, ctx))) -> Reader(List(v), ctx) {
  use <- function.return(map(_, list.reverse))
  use list, reader <- list.fold(readers, return([]))
  map2(list, reader, list.prepend)
}
