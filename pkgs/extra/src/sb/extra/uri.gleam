import gleam/list
import gleam/option
import gleam/result
import gleam/uri.{type Uri}

pub fn get_query(uri: Uri, name: String) -> Result(String, Nil) {
  option.map(uri.query, uri.parse_query)
  |> option.map(result.unwrap(_, []))
  |> option.unwrap([])
  |> list.key_find(name)
}

pub fn optional_query(uri: Uri, name: String) -> String {
  get_query(uri, name) |> result.unwrap("")
}
