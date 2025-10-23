import gleam/bool
import gleam/list
import gleam/string

pub fn words(string: String) -> List(String) {
  use word <- list.filter_map(string.split(string, " "))
  let word = string.trim(word)
  use <- bool.guard(string.is_empty(word), Error(Nil))
  Ok(word)
}
