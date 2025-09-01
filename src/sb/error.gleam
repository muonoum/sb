import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/json
import gleam/set.{type Set}
import sb/parser
import sb/report.{type Report}
import sb/value.{type Value}

pub type Error {
  FieldContext(String)

  Collected(List(Report(Error)))

  DuplicateId(String)
  Message(String)
  Required
  Expected(Value)

  MissingProperty(String)

  UnknownKeys(List(String))
  UnknownKind(String)

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
  known_keys: List(String),
) -> Result(Dict(String, v), Report(Error)) {
  let defined_set = set.from_list(dict.keys(dict))
  let known_set = set.from_list(known_keys)
  let unknown_keys = set.to_list(set.difference(defined_set, known_set))
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
