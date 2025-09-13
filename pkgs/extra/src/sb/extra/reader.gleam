import sb/extra/function.{identity}

pub type Reader(v, ctx) {
  Reader(run: fn(ctx) -> v)
}

pub const ask = Reader(identity)

// pub fn ask() -> Reader(ctx, ctx) {
//   Reader(identity)
// }

// pub fn asks(sel: fn(Reader(c, d)) -> Reader(e, c)) -> Reader(e, c) {
//   do(ask, compose(return, sel))
// }

// pub fn local(r: Reader(v, ctx), f: fn(ctx) -> ctx) -> Reader(v, ctx) {
//   use context <- Reader
//   r.run(f(context))
// }

pub fn return(value: v) -> Reader(v, ctx) {
  use _ <- Reader
  value
}

pub fn do(
  reader: Reader(a, ctx),
  then: fn(a) -> Reader(b, ctx),
) -> Reader(b, ctx) {
  use context <- Reader
  then(reader.run(context)).run(context)
}

pub fn main() {
  todo
}
