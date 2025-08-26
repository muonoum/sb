import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/set.{type Set}
import sb/condition.{type Condition}
import sb/error.{type Error}
import sb/filter.{type Filter}
import sb/handlers.{type Handlers}
import sb/kind.{type Kind}
import sb/report.{type Report}
import sb/reset.{type Reset}
import sb/scope.{type Scope}
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

pub fn decoder(
  dynamic: Dynamic,
  fields: Dict(String, Dict(String, Dynamic)),
  filters: Dict(String, Dict(String, Dynamic)),
) -> Result(#(String, Field), Report(Error)) {
  decode.run(dynamic, decode.dict(decode.string, decode.dynamic))
  |> report.map_error(error.DecodeError)
  |> result.try(dict_decoder(_, fields, filters))
}

fn dict_decoder(
  dict: Dict(String, Dynamic),
  fields: Dict(String, Dict(String, Dynamic)),
  filters: Dict(String, Dict(String, Dynamic)),
) -> Result(#(String, Field), Report(Error)) {
  use kind <- result.try(case dict.get(dict, "kind") {
    Error(Nil) -> error.missing_property("kind")

    Ok(dynamic) ->
      decode.run(dynamic, decode.string)
      |> error.bad_property("category")
  })

  case dict.get(fields, kind) {
    Ok(custom) -> dict_decoder(dict.merge(dict, custom), fields, filters)
    Error(Nil) -> kind_decoder(kind, dict, filters)
  }
}

fn kind_decoder(
  kind: String,
  dict: Dict(String, Dynamic),
  filters: Dict(String, Dict(String, Dynamic)),
) -> Result(#(String, Field), Report(Error)) {
  use kind <- result.try({
    use kind_keys <- result.try(kind.keys(kind))
    error.unknown_keys(dict, [field_keys, kind_keys])
    |> result.try(kind.decoder(kind, _))
  })

  use id <- result.try({
    case dict.get(dict, "id") {
      Error(Nil) -> error.missing_property("id")

      Ok(dynamic) ->
        decode.run(dynamic, decode.string)
        |> error.bad_property("id")
    }
  })

  use label <- result.try({
    case dict.get(dict, "label") {
      Error(Nil) -> Ok(None)

      Ok(dynamic) ->
        decode.run(dynamic, decode.string)
        |> error.bad_property("label")
        |> result.map(Some)
    }
  })

  use description <- result.try({
    case dict.get(dict, "description") {
      Error(Nil) -> Ok(None)

      Ok(dynamic) ->
        decode.run(dynamic, decode.string)
        |> error.bad_property("description")
        |> result.map(Some)
    }
  })

  use disabled <- result.try({
    case dict.get(dict, "disabled") {
      Error(Nil) -> Ok(condition.false())

      Ok(dynamic) ->
        condition.decoder(dynamic)
        |> report.error_context(error.BadProperty("disabled"))
    }
  })

  use hidden <- result.try({
    case dict.get(dict, "hidden") {
      Error(Nil) -> Ok(condition.false())

      Ok(dynamic) ->
        condition.decoder(dynamic)
        |> report.error_context(error.BadProperty("hidden"))
    }
  })

  use ignored <- result.try({
    case dict.get(dict, "ignored") {
      Error(Nil) -> Ok(condition.false())

      Ok(dynamic) ->
        condition.decoder(dynamic)
        |> report.error_context(error.BadProperty("ignored"))
    }
  })

  use optional <- result.try({
    case dict.get(dict, "optional") {
      Error(Nil) -> Ok(condition.false())

      Ok(dynamic) ->
        condition.decoder(dynamic)
        |> report.error_context(error.BadProperty("optional"))
    }
  })

  use filters <- result.try({
    case dict.get(dict, "filters") {
      Error(Nil) -> Ok([])

      Ok(dynamic) -> {
        use list <- result.try(
          decode.run(dynamic, decode.list(decode.dynamic))
          |> error.bad_property("filters"),
        )

        list.try_map(list, filter.decoder(_, filters))
      }
    }
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

  Ok(#(id, field))
}
