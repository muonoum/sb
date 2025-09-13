import gleam/list

pub type Writer(v, ctx) {
  Writer(#(v, List(ctx)))
}

pub fn return(value: v) -> Writer(v, ctx) {
  Writer(#(value, []))
}

pub fn do(
  writer: Writer(a, ctx),
  then: fn(a) -> Writer(b, ctx),
) -> Writer(b, ctx) {
  let Writer(#(a, context1)) = writer
  let Writer(#(b, context2)) = then(a)
  Writer(#(b, list.append(context1, context2)))
}

pub fn tell(context: List(ctx)) -> Writer(Nil, ctx) {
  Writer(#(Nil, context))
}

fn log(value) {
  use _ <- do(tell([value]))
  return(value)
}

pub fn main() {
  let x = {
    use a <- do(log(10))
    use b <- do(log(20))
    return(a + b)
  }

  echo x
}
