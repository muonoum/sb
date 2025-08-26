import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/set
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

pub fn missing_property(name: String) -> Result(v, Report(Error)) {
  report.error(MissingProperty(name))
}

pub fn bad_property(
  result: Result(v, List(decode.DecodeError)),
  name: String,
) -> Result(v, Report(Error)) {
  report.map_error(result, DecodeError)
  |> report.error_context(BadProperty(name))
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
