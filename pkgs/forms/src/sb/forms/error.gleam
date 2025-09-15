import exception.{type Exception}
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/pair
import gleam/regexp
import gleam/result
import gleam/set
import sb/extra/function.{return}
import sb/extra/parser
import sb/extra/report.{type Report}
import sb/forms/value.{type Value}

pub type Error {
  FieldContext(String)
  PathContext(String)
  IndexContext(Int)

  DuplicateId(String)
  DuplicateKey(Value)
  DuplicateNames(name: String, category: List(String))
  EmptyFile
  Expected(Value)
  Message(String)
  NotFound(String)
  Recursive(String)
  Required

  MissingProperty(String)

  UnknownKeys(List(String))
  UnknownKind(String)

  BadId(String)
  BadKind(String)
  BadProperty(String)
  BadSource
  BadValue(Value)
  BadCondition(String)

  FileError
  DecodeError(List(decode.DecodeError))
  JsonError(json.DecodeError)
  RegexError(regexp.CompileError)
  TextError(parser.Message(String))
  YamlError(Exception)
}

pub fn unique_keys(value: Value) -> Result(List(Value), Report(Error)) {
  use keys <- result.try(
    value.keys(value)
    |> report.replace_error(BadValue(value)),
  )

  use <- return(result.map(_, pair.second))
  let keys = list.reverse(keys)
  use #(seen, keys), key <- list.try_fold(keys, #(set.new(), []))
  case set.contains(seen, key) {
    True -> report.error(DuplicateKey(key))
    False -> Ok(#(set.insert(seen, key), [key, ..keys]))
  }
}
