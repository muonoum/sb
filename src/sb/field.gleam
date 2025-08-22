import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/set.{type Set}
import sb/error.{type Error}
import sb/filter
import sb/kind.{type Kind}
import sb/scope.{type Scope}
import sb/value.{type Value}

pub type Field {
  Field(kind: Kind)
}

pub fn reset(field: Field, refs: Set(String)) -> Field {
  Field(kind: kind.reset(field.kind, refs))
}

pub fn evaluate(field: Field, scope: Scope) {
  Field(kind: kind.evaluate(field.kind, scope))
}

pub fn update(field: Field, value: Value) -> Result(Field, Error) {
  use kind <- result.try(kind.update(field.kind, value))
  Ok(Field(kind:))
}

pub fn value(field: Field) {
  let optional = True

  case kind.value(field.kind) {
    None if optional -> None
    None -> Some(Error(error.Required))
    Some(Error(error)) -> Some(Error(error))
    Some(Ok(value)) -> Some(list.try_fold([], value, filter.evaluate))
  }
}
