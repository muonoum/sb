import gleam/result

pub fn nil(_) -> Nil {
  Nil
}

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

pub fn fix0(fun: fn(fn() -> a) -> a) -> fn() -> a {
  use <- identity
  fix0(fun) |> fun()
}

pub fn fix1(fun: fn(fn(a) -> b, a) -> b) -> fn(a) -> b {
  use a <- identity
  fix1(fun) |> fun(a)
}

pub fn fix2(fun: fn(fn(a, b) -> c, a, b) -> c) -> fn(a, b) -> c {
  use a, b <- identity
  fix2(fun) |> fun(a, b)
}

pub fn fix3(fun: fn(fn(a, b, c) -> d, a, b, c) -> d) -> fn(a, b, c) -> d {
  use a, b, c <- identity
  fix3(fun) |> fun(a, b, c)
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
