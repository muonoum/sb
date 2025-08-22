import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/set.{type Set}
import sb/condition.{type Condition}
import sb/error.{type Error}
import sb/filter
import sb/kind.{type Kind}
import sb/reset.{type Reset}
import sb/scope.{type Scope}
import sb/value.{type Value}

pub opaque type Field {
  Field(kind: Kind, optional: Reset(Condition))
}

pub fn kind(field: Field) -> Kind {
  field.kind
}

pub fn new(kind: Kind) -> Field {
  let optional = condition.false()
  Field(kind:, optional: reset.new(optional, condition.refs(optional)))
}

pub fn reset(field: Field, refs: Set(String)) -> Field {
  Field(
    kind: kind.reset(field.kind, refs),
    optional: reset.maybe(field.optional, refs),
  )
}

pub fn evaluate(field: Field, scope: Scope) {
  Field(
    kind: kind.evaluate(field.kind, scope),
    optional: reset.map(field.optional, condition.evaluate(_, scope)),
  )
}

pub fn update(field: Field, value: Value) -> Result(Field, Error) {
  use kind <- result.try(kind.update(field.kind, value))
  Ok(Field(..field, kind:))
}

pub fn value(field: Field) {
  let optional =
    reset.unwrap(field.optional)
    |> condition.is_true

  case kind.value(field.kind) {
    None if optional -> None
    None -> Some(Error(error.Required))
    Some(Error(error)) -> Some(Error(error))
    Some(Ok(value)) -> Some(list.try_fold([], value, filter.evaluate))
  }
}
