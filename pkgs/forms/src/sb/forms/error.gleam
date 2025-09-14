import exception.{type Exception}
import gleam/dynamic/decode
import gleam/json
import gleam/regexp
import sb/extra/parser
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
