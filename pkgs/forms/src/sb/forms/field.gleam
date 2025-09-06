import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/set.{type Set}
import sb/extra
import sb/extra/report.{type Report}
import sb/extra/reset.{type Reset}
import sb/extra/state
import sb/forms/condition.{type Condition}
import sb/forms/custom
import sb/forms/decoder
import sb/forms/error.{type Error}
import sb/forms/filter.{type Filter}
import sb/forms/handlers.{type Handlers}
import sb/forms/kind.{type Kind}
import sb/forms/props.{type Props}
import sb/forms/scope.{type Scope}
import sb/forms/text
import sb/forms/value.{type Value}
import sb/forms/zero

const field_keys = [
  "id", "kind", "label", "description", "disabled", "hidden", "ignored",
  "optional", "filters",
]

const filter_keys = ["kind"]

pub type Field {
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

fn kind_decoder(
  custom: custom,
  get: fn(custom, String) -> Result(Dict(String, Dynamic), _),
  then: fn(String) -> Props(v),
) -> Props(v) {
  use name <- props.get("kind", decoder.from(decode.string))

  use <- result.lazy_unwrap({
    use dict <- result.map(get(custom, name))
    use <- state.do(props.merge(dict))
    kind_decoder(custom, get, then)
  })

  then(name)
}

pub fn decoder(
  fields: custom.Fields,
  sources: custom.Sources,
  filters: custom.Filters,
) -> Props(#(String, Field)) {
  use id <- props.get("id", text.id_decoder)
  use <- extra.return(props.error_context(error.FieldContext(id)))

  use kind <- state.with({
    use name <- kind_decoder(fields, custom.get_field)
    use kind_keys <- kind.decoder(name, sources)
    props.check_keys(list.append(field_keys, kind_keys))
  })

  use label <- props.try("label", zero.option(decoder.from(decode.string)))

  use description <- props.try("description", {
    zero.option(decoder.from(decode.string))
  })

  use disabled <- props.try("disabled", condition.decoder())
  use hidden <- props.try("hidden", condition.decoder())
  use ignored <- props.try("ignored", condition.decoder())
  use optional <- props.try("optional", condition.decoder())

  use filters <- props.try("filters", {
    use dynamic <- zero.list
    use list <- result.try(decoder.run(dynamic, decode.list(decode.dynamic)))
    use dynamic <- list.try_map(list)

    props.decode(dynamic, {
      use name <- kind_decoder(filters, custom.get_filter)
      use kind_keys <- filter.decoder(name)
      props.check_keys(list.append(filter_keys, kind_keys))
    })
  })

  let field =
    Field(
      kind:,
      label:,
      description:,
      disabled: reset.new(disabled, condition.refs),
      hidden: reset.new(hidden, condition.refs),
      ignored: reset.new(ignored, condition.refs),
      optional: reset.new(optional, condition.refs),
      filters:,
    )

  state.succeed(#(id, field))
}
