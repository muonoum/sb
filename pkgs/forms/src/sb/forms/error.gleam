import exception.{type Exception}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/pair
import gleam/regexp
import gleam/result
import gleam/set
import sb/extra/dynamic as dynamic_extra
import sb/extra/function.{return}
import sb/extra/parser
import sb/extra/report.{type Report}
import sb/forms/value.{type Value}

pub type Error {
  FieldContext(String)
  PathContext(String)
  IndexContext(Int)

  Todo(String)
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
  BadFormat(Dynamic)

  DecodeError(List(decode.DecodeError))
  FileError
  HttpError(Dynamic)
  JsonError(json.DecodeError)
  RegexError(regexp.CompileError)
  TextError(parser.Message(String))
  YamlError(Exception)
}

pub fn field_context(error: Error) -> Result(String, Nil) {
  case error {
    FieldContext(id) -> Ok(id)
    _error -> Error(Nil)
  }
}

pub fn bad_format(data: any) -> Error {
  BadFormat(dynamic_extra.from(data))
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
