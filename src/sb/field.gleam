import extra
import extra/state
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pair
import gleam/result
import gleam/set.{type Set}
import sb/condition.{type Condition}
import sb/custom
import sb/decoder
import sb/error.{type Error}
import sb/filter.{type Filter}
import sb/handlers.{type Handlers}
import sb/kind.{type Kind}
import sb/props.{type Props}
import sb/report.{type Report}
import sb/reset.{type Reset}
import sb/scope.{type Scope}
import sb/text
import sb/value.{type Value}

const field_keys = [
  "id", "kind", "label", "description", "disabled", "hidden", "ignored",
  "optional", "filters",
]

pub opaque type Field {
  Field(
    kind: Kind,
    label: Option(String),
    description: Option(String),
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
  Field(
    kind:,
    label: None,
    description: None,
    disabled: reset.new(condition.false(), condition.refs),
    hidden: reset.new(condition.false(), condition.refs),
    ignored: reset.new(condition.false(), condition.refs),
    optional: reset.new(condition.false(), condition.refs),
    filters: [],
  )
}

pub fn optional(field: Field, state: Bool) -> Field {
  let optional = condition.resolved(state)
  Field(..field, optional: reset.new(optional, condition.refs))
}

pub fn reset(field: Field, refs: Set(String)) -> Field {
  Field(
    ..field,
    kind: kind.reset(field.kind, refs),
    disabled: reset.maybe(field.disabled, refs),
    hidden: reset.maybe(field.hidden, refs),
    ignored: reset.maybe(field.ignored, refs),
    optional: reset.maybe(field.optional, refs),
  )
}

pub fn evaluate(
  field: Field,
  scope: Scope,
  search: Option(String),
  handlers: Handlers,
) -> Field {
  Field(
    ..field,
    kind: kind.evaluate(field.kind, scope, search, handlers),
    disabled: reset.map(field.disabled, condition.evaluate(_, scope)),
    hidden: reset.map(field.hidden, condition.evaluate(_, scope)),
    ignored: reset.map(field.ignored, condition.evaluate(_, scope)),
    optional: reset.map(field.optional, condition.evaluate(_, scope)),
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

pub fn unique_decoder(
  fields: custom.Fields,
  filters: custom.Filters,
) -> fn(Dynamic) ->
  Result(List(Result(#(String, Field), Report(Error))), Report(Error)) {
  fn(dynamic: Dynamic) {
    use list <- result.map(decoder.run(dynamic, decode.list(decode.dynamic)))
    use <- extra.return(pair.second)
    use seen, dynamic <- list.map_fold(list, set.new())
    props.decode(dynamic, decoder(fields, filters))
    |> error.try_duplicate_ids(seen)
  }
}

pub fn decoder(
  fields: custom.Fields,
  filters: custom.Filters,
) -> Props(#(String, Field)) {
  use id <- props.required("id", decoder.zero_string(text.id_decoder))

  use <- extra.return(
    state.map_error(_, report.context(_, error.FieldContext(id))),
  )

  use kind <- state.with(
    kind.decoder(fields, fn(kind_keys) {
      list.append(field_keys, kind_keys)
      |> props.check_keys
    }),
  )

  use label <- props.zero("label", {
    decoder.zero_option(decoder.from(decode.map(decode.string, Some)))
  })

  use description <- props.zero("description", {
    decoder.zero_option(decoder.from(decode.map(decode.string, Some)))
  })

  let condition = decoder.zero(condition.decoder, condition.false)

  use disabled <- props.zero("disabled", condition)
  use hidden <- props.zero("hidden", condition)
  use ignored <- props.zero("ignored", condition)
  use optional <- props.zero("optional", condition)

  use filters <- props.zero("filters", {
    decoder.zero_list(fn(dynamic) {
      decoder.run(dynamic, decode.list(decode.dynamic))
      |> result.try(list.try_map(_, props.decode(_, filter.decoder(filters))))
    })
  })

  state.succeed(#(
    id,
    Field(
      kind:,
      label:,
      description:,
      disabled: reset.new(disabled, condition.refs),
      hidden: reset.new(hidden, condition.refs),
      ignored: reset.new(ignored, condition.refs),
      optional: reset.new(optional, condition.refs),
      filters:,
    ),
  ))
}
