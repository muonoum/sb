pub fn identity(value: v) -> v {
  value
}

pub fn nullary(value: v) -> fn() -> v {
  fn() { value }
}

pub fn fix(op: fn(fn(a) -> b, a) -> b) -> fn(a) -> b {
  fn(value) { op(fix(op), value) }
}

pub fn return(a: fn(a) -> b, body: fn() -> a) -> b {
  a(body())
}
