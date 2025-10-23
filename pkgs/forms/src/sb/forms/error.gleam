import exception.{type Exception}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/json
import gleam/regexp
import sb/extra/dynamic as dynamic_extra
import sb/extra/parser
import sb/forms/value.{type Value}

pub type Error {
  Todo(String)

  FieldContext(String)
  IndexContext(Int)
  PathContext(String)

  DuplicateId(String)
  DuplicateKeys(List(Value))
  DuplicateNames(name: String, category: List(String))

  Dynamic(Dynamic)
  Expected(Value)
  Message(String)
  Recursive(String)
  Required
  Unmatched(String)

  MissingProperty(String)

  UnknownKeys(List(String))
  UnknownKind(String)

  BadCommand
  BadCondition(String)
  BadFilter
  BadFormat(Dynamic)
  BadId(String)
  BadKind(String)
  BadProperty(String)
  BadRequest
  BadSource
  BadValue(Value)

  BadFile
  EmptyFile

  CommandError(exit_code: Int, output: String)
  DecodeError(List(decode.DecodeError))
  TcpError(Dynamic)
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

pub fn dyanmic(data: any) -> Error {
  Dynamic(dynamic_extra.from(data))
}
