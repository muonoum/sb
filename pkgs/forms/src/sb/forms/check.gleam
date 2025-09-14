import exception.{type Exception}
import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/pair
import gleam/regexp
import gleam/result
import gleam/set.{type Set}
import sb/extra/function.{return}
import sb/extra/parser
import sb/extra/report.{type Report}
import sb/forms/error.{type Error}
import sb/forms/value.{type Value}

pub fn known_keys(
  dict: Dict(String, v),
  known_keys: List(String),
) -> Result(Dict(String, v), Report(Error)) {
  let defined_set = set.from_list(dict.keys(dict))
  let known_set = set.from_list(known_keys)
  let unknown_keys = set.to_list(set.difference(defined_set, known_set))
  use <- bool.guard(unknown_keys == [], Ok(dict))
  report.error(error.UnknownKeys(unknown_keys))
}

pub fn try_unique_id(
  result: Result(#(String, v), Report(Error)),
  seen: Set(String),
) -> #(Set(String), Result(#(String, v), Report(Error))) {
  case result {
    Error(report) -> #(seen, Error(report))

    Ok(#(id, field)) ->
      case set.contains(seen, id) {
        True -> #(seen, report.error(error.DuplicateId(id)))
        False -> #(set.insert(seen, id), Ok(#(id, field)))
      }
  }
}

pub fn unique_keys(value) {
  use keys <- result.try(
    value.keys(value)
    |> report.replace_error(error.BadValue(value)),
  )

  use <- return(result.map(_, pair.second))
  let keys = list.reverse(keys)
  use #(seen, keys), key <- list.try_fold(keys, #(set.new(), []))
  case set.contains(seen, key) {
    True -> report.error(error.DuplicateKey(key))
    False -> Ok(#(set.insert(seen, key), [key, ..keys]))
  }
}
