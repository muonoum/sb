import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/set.{type Set}
import sb/extra/function.{return}
import sb/extra/reader.{type Reader}
import sb/extra/report.{type Report}
import sb/extra/reset.{type Reset}
import sb/extra/state
import sb/forms/condition.{type Condition}
import sb/forms/custom
import sb/forms/decoder
import sb/forms/error.{type Error}
import sb/forms/evaluate
import sb/forms/filter.{type Filter}
import sb/forms/kind.{type Kind}
import sb/forms/props
import sb/forms/source.{type Source}
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
  search: Option(String),
) -> Reader(Field, evaluate.Context) {
  use kind <- reader.bind(kind.evaluate(field.kind, search))

  let evaluate_condition = evaluate.reset(_, condition.evaluate)
  use disabled <- reader.bind(evaluate_condition(field.disabled))
  use hidden <- reader.bind(evaluate_condition(field.hidden))
  use ignored <- reader.bind(evaluate_condition(field.ignored))
  use optional <- reader.bind(evaluate_condition(field.optional))

  reader.return(Field(..field, kind:, disabled:, hidden:, ignored:, optional:))
}

pub fn update(
  field: Field,
  value: Option(Value),
) -> Result(Field, Report(Error)) {
  use kind <- result.try(kind.update(field.kind, value))
  Ok(Field(..field, kind:))
}

// TODO: Kjører i evaluate-context pga. filterne. Se på å flytte dette
// til evaluate slik at vi kan droppe reader her.
pub fn value(
  field: Field,
) -> Reader(Option(Result(Value, Report(Error))), evaluate.Context) {
  use task_commands <- reader.bind(evaluate.get_task_commands())
  use handlers <- reader.bind(evaluate.get_handlers())
  use <- return(reader.return)

  let optional =
    reset.unwrap(field.optional)
    |> condition.is_true

  case kind.value(field.kind) {
    None if optional -> None
    None -> Some(report.error(error.Required))
    Some(Error(report)) -> Some(Error(report))

    Some(Ok(value)) -> {
      use <- return(Some)
      use value, filter <- list.try_fold(field.filters, value)
      filter.evaluate(value, filter, task_commands:, handlers:)
    }
  }
}

// TODO: Hvor bør denne funksjonen plasseres?
pub fn is_loading(
  field_id: String,
  source: Source,
  fields: Dict(String, Field),
) -> Bool {
  use <- bool.guard(when: source.is_loading(source), return: True)
  use ref <- list.any(source.refs(source))
  // unngå sirkulære referanser
  use <- bool.guard(when: field_id == ref, return: False)
  let check_source = is_loading(field_id, _, fields)

  case dict.get(fields, ref) {
    Ok(field) -> kind.is_loading(field.kind, check_source)
    Error(Nil) -> False
  }
}

pub fn decoder(
  sources sources: custom.Sources,
  fields fields: custom.Fields,
  filters filters: custom.Filters,
) -> props.Try(#(String, Field)) {
  use id <- props.get("id", text.id_decoder)
  use <- return(props.error_context(error.FieldContext(id)))

  use kind <- state.try_bind({
    use _seen, name <- custom.kind_decoder(set.new(), fields, custom.get_field)
    use kind_keys <- kind.decoder(name, sources:)
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
    use <- return(props.decode(dynamic, _))
    use _, name <- custom.kind_decoder(set.new(), filters, custom.get_filter)
    use kind_keys <- filter.decoder(name)
    props.check_keys(list.append(filter_keys, kind_keys))
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

  state.ok(#(id, field))
}
