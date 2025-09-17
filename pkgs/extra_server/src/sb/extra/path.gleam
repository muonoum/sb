import gleam/erlang/charlist.{type Charlist}
import gleam/list

@external(erlang, "filename", "basename")
pub fn base(path: String) -> String

@external(erlang, "filename", "absname")
pub fn absolute(path: String) -> String

@external(erlang, "filename", "join")
pub fn join(components: List(String)) -> String

@external(erlang, "filename", "extension")
pub fn extension(name: String) -> String

@external(erlang, "filelib", "wildcard")
fn filelib_wildcard(pattern: Charlist, cwd: Charlist) -> List(Charlist)

pub fn wildcard(cwd: String, pattern: String) -> List(String) {
  charlist.from_string(pattern)
  |> filelib_wildcard(charlist.from_string(cwd))
  |> list.map(charlist.to_string)
}
