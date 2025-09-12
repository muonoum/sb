import gleam/bool
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/uri.{type Uri}

pub type Visibility {
  Visible
  Hidden
}

pub fn non_empty_list(list: List(a), empty: b, then: fn(a, List(a)) -> b) -> b {
  case list {
    [] -> empty
    [first, ..rest] -> then(first, rest)
  }
}

pub fn compose(a: fn(a) -> b, b: fn(b) -> c) -> fn(a) -> c {
  fn(v) { b(a(v)) }
}

pub fn identity(value: v) -> v {
  value
}

pub fn id2(f: fn(a, b) -> c, then: b) -> fn(a) -> c {
  fn(a) { f(a, then) }
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

pub fn words(string: String) -> List(String) {
  use word <- list.filter_map(string.split(string, " "))
  let value = string.trim
  let word = value(word)
  use <- bool.guard(string.is_empty(word), Error(Nil))
  Ok(word)
}

pub fn get_query(uri: Uri, name: String) -> String {
  option.map(uri.query, uri.parse_query)
  |> option.map(result.unwrap(_, []))
  |> option.unwrap([])
  |> list.key_find(name)
  |> result.unwrap("")
}
