import gleam/result

pub fn compose(a: fn(a) -> b, b: fn(b) -> c) -> fn(a) -> c {
  fn(v) { b(a(v)) }
}

pub fn identity(value: v) -> v {
  value
}

pub fn nullary(value: v) -> fn() -> v {
  fn() { value }
}

pub fn fix(f: fn(fn(a) -> b, a) -> b) -> fn(a) -> b {
  fn(v) { f(fix(f), v) }
}

pub fn return(a: fn(a) -> b, body: fn() -> a) -> b {
  a(body())
}

pub fn unwrap(value: v, body: fn() -> Result(v, _)) -> v {
  return(result.unwrap(_, value), body)
}

pub fn lazy_unwrap(value: fn() -> v, body: fn() -> Result(v, _)) -> v {
  return(result.lazy_unwrap(_, value), body)
}

pub fn apply(v: a) -> fn(fn(a) -> b) -> b {
  fn(f) { f(v) }
}

pub fn lazy_apply(v: fn() -> a) -> fn(fn(a) -> b) -> b {
  fn(f) { f(v()) }
}
