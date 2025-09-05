pub fn identity(value: v) -> v {
  value
}

pub fn fix(f: fn(fn(a) -> b, a) -> b) -> fn(a) -> b {
  fn(v) { f(fix(f), v) }
}

pub fn return(a: fn(a) -> b, body: fn() -> a) -> b {
  a(body())
}
