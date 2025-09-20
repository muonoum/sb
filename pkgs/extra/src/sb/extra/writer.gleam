import sb/extra/diff_list.{type DList} as diff

pub type Writer(v, ctx) {
  Writer(v, DList(ctx))
}

pub fn run(writer: Writer(v, ctx)) -> #(v, List(ctx)) {
  let Writer(v, ctx) = writer
  #(v, diff.to_list(ctx))
}

pub fn return(value: v) -> Writer(v, ctx) {
  Writer(value, diff.new())
}

pub fn bind(
  writer: Writer(a, ctx),
  then: fn(a) -> Writer(b, ctx),
) -> Writer(b, ctx) {
  let Writer(a, ctx1) = writer
  let Writer(b, ctx2) = then(a)
  Writer(b, diff.append(ctx1, ctx2))
}

pub fn do(
  writer: Writer(a, ctx),
  then: fn() -> Writer(b, ctx),
) -> Writer(b, ctx) {
  bind(writer, fn(_) { then() })
}

pub fn map(writer: Writer(a, ctx), mapper: fn(a) -> b) -> Writer(b, ctx) {
  let Writer(a, ctx) = writer
  Writer(mapper(a), ctx)
}

pub fn put(ctx: List(ctx)) -> Writer(Nil, ctx) {
  Writer(Nil, diff.from_list(ctx))
}
