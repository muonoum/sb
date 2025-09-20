import gleam/bool
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/uri.{type Uri}

pub opaque type Never {
  JustOneMore(Never)
}

pub fn never(v: Never) -> v {
  let JustOneMore(x) = v
  never(x)
}

pub type Visibility {
  Visible
  Hidden
}

pub fn words(string: String) -> List(String) {
  use word <- list.filter_map(string.split(string, " "))
  let word = string.trim(word)
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
