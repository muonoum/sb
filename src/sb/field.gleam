import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/set.{type Set}
import sb/condition.{type Condition}
import sb/error.{type Error}
import sb/filter.{type Filter}
import sb/kind.{type Kind}
import sb/report.{type Report}
import sb/reset.{type Reset}
import sb/scope.{type Scope}
import sb/value.{type Value}

pub opaque type Field {
  Field(
    kind: Kind,
    disabled: Reset(Condition),
    hidden: Reset(Condition),
    ignored: Reset(Condition),
    optional: Reset(Condition),
    filters: List(Filter),
  )
}

pub fn kind(field: Field) -> Kind {
  field.kind
}

pub fn new(kind: Kind) -> Field {
  let disabled = condition.false()
  let hidden = condition.false()
  let ignored = condition.false()
  let optional = condition.false()

  Field(
    kind:,
    disabled: reset.new(disabled, condition.refs(disabled)),
    hidden: reset.new(hidden, condition.refs(hidden)),
    ignored: reset.new(ignored, condition.refs(ignored)),
    optional: reset.new(optional, condition.refs(optional)),
    filters: [],
  )
}

pub fn optional(field: Field, state: Bool) -> Field {
  let optional = condition.resolved(state)
  let refs = condition.refs(optional)
  Field(..field, optional: reset.new(optional, refs))
}

pub fn reset(field: Field, refs: Set(String)) -> Field {
  Field(
    kind: kind.reset(field.kind, refs),
    disabled: reset.maybe(field.disabled, refs),
    hidden: reset.maybe(field.hidden, refs),
    ignored: reset.maybe(field.ignored, refs),
    optional: reset.maybe(field.optional, refs),
    filters: field.filters,
  )
}

pub fn evaluate(field: Field, scope: Scope) {
  Field(
    kind: kind.evaluate(field.kind, scope),
    disabled: reset.map(field.disabled, condition.evaluate(_, scope)),
    hidden: reset.map(field.hidden, condition.evaluate(_, scope)),
    ignored: reset.map(field.ignored, condition.evaluate(_, scope)),
    optional: reset.map(field.optional, condition.evaluate(_, scope)),
    filters: field.filters,
  )
}

pub fn update(field: Field, value: Value) -> Result(Field, Report(Error)) {
  use kind <- result.try(kind.update(field.kind, value))
  Ok(Field(..field, kind:))
}

pub fn value(field: Field) -> Option(Result(Value, Report(Error))) {
  let optional =
    reset.unwrap(field.optional)
    |> condition.is_true

  case kind.value(field.kind) {
    None if optional -> None
    None -> Some(report.error(error.Required))
    Some(Error(report)) -> Some(Error(report))

    Some(Ok(value)) ->
      Some(list.try_fold(field.filters, value, filter.evaluate))
  }
}
