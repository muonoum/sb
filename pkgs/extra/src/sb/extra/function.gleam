import gleam/result

pub fn constant(value: v) -> fn(_) -> v {
  fn(_) { value }
}

pub fn compose(a: fn(a) -> b, b: fn(b) -> c) -> fn(a) -> c {
  fn(v) { b(a(v)) }
}

pub fn compose2(a: fn(a) -> b, b: fn(b) -> c, c: fn(c) -> d) -> fn(a) -> d {
  fn(v) { c(b(a(v))) }
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

pub fn return(wrap: fn(a) -> b, body: fn() -> a) -> b {
  wrap(body())
}

pub fn replace(wrap: fn(fn(_) -> a) -> b, body: fn() -> a) -> b {
  wrap(fn(_) { body() })
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
