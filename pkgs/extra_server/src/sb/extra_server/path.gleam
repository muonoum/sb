import filepath
import gleam/bool
import gleam/erlang/charlist.{type Charlist}
import gleam/list
import gleam/result

// TODO
pub fn relative(path path: String, to cwd: String) -> Result(String, Nil) {
  use path <- result.try(filepath.expand(path) |> result.map(filepath.split))
  use <- bool.guard(path == [], Ok("."))
  use cwd <- result.try(filepath.expand(cwd) |> result.map(filepath.split))
  Ok(relative_loop(path, cwd, path))
}

fn relative_loop(a: List(String), b: List(String), path: List(String)) -> String {
  case a, b {
    a, b if a == b -> "."
    [a, ..ar], [b, ..br] if a == b -> relative_loop(ar, br, path)
    [_, ..] as a, [] -> join(a)
    _a, _b -> join(path)
  }
}

@external(erlang, "file", "get_cwd")
fn file_get_cwd() -> Result(Charlist, Nil)

pub fn get_cwd() -> Result(String, Nil) {
  file_get_cwd() |> result.map(charlist.to_string)
}

@external(erlang, "glue", "find_executable")
pub fn find_executable(name: String) -> Result(String, Nil)

@external(erlang, "filename", "absname")
pub fn absolute(path: String) -> String

@external(erlang, "filename", "absname")
pub fn absolute_from(path: String, from: String) -> String

@external(erlang, "filename", "join")
pub fn join(components: List(String)) -> String

@external(erlang, "filelib", "wildcard")
fn filelib_wildcard(pattern: Charlist, cwd: Charlist) -> List(Charlist)

pub fn wildcard(cwd: String, pattern: String) -> List(String) {
  charlist.from_string(pattern)
  |> filelib_wildcard(charlist.from_string(cwd))
  |> list.map(charlist.to_string)
}
