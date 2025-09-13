import gleam/set.{type Set}

pub opaque type Writer(v, ctx) {
  Writer(v, Set(ctx))
}

pub fn return(value: v) -> Writer(v, ctx) {
  Writer(value, set.new())
}

pub fn bind(
  writer: Writer(a, ctx),
  then: fn(a) -> Writer(b, ctx),
) -> Writer(b, ctx) {
  let Writer(a, ctx1) = writer
  let Writer(b, ctx2) = then(a)
  Writer(b, set.union(ctx1, ctx2))
}

pub fn do(writer, then) {
  bind(writer, fn(_) { then() })
}

pub fn tell(ctx: ctx) -> Writer(Nil, ctx) {
  Writer(Nil, set.insert(set.new(), ctx))
}

pub fn main() {
  let x = {
    use <- do(tell("a"))
    use <- do(tell("b"))
    return(10)
  }

  echo x
}
