import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/set.{type Set}
import sb/parser
import sb/report.{type Report}
import sb/value.{type Value}

pub type Error {
  Collected(List(Report(Error)))

  DuplicateId(String)
  Message(String)
  Required
  UnknownKeys(List(String))
  UnknownKind(String)

  MissingProperty(String)

  BadId(String)
  BadKind(String)
  BadProperty(String)
  BadSource
  BadValue(Value)

  DecodeError(List(decode.DecodeError))
  JsonError(json.DecodeError)
  TextError(parser.Message(String))
}

pub fn unknown_keys(
  dict: Dict(String, v),
  known_keys: List(List(String)),
) -> Result(Dict(String, v), Report(Error)) {
  let unknown_keys =
    set.to_list(
      set.from_list(dict.keys(dict))
      |> set.difference(
        list.map(known_keys, set.from_list)
        |> list.fold(set.new(), set.union),
      ),
    )

  use <- bool.guard(unknown_keys == [], Ok(dict))
  report.error(UnknownKeys(unknown_keys))
}

pub fn try_duplicate_ids(
  result: Result(#(String, v), Report(Error)),
  seen: Set(String),
) -> #(Set(String), Result(#(String, v), Report(Error))) {
  case result {
    Error(report) -> #(seen, Error(report))

    Ok(#(id, field)) ->
      case set.contains(seen, id) {
        True -> #(seen, report.error(DuplicateId(id)))
        False -> #(set.insert(seen, id), Ok(#(id, field)))
      }
  }
}
