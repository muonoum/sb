import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option}
import gleam/pair
import gleam/result
import gleam/set.{type Set}
import gleam/string
import sb/extra/function.{identity, return}
import sb/extra/report.{type Report}
import sb/extra/state_eval as state
import sb/forms/access.{type Access}
import sb/forms/custom
import sb/forms/decoder
import sb/forms/error.{type Error}
import sb/forms/field.{type Field}
import sb/forms/handlers.{type Handlers}
import sb/forms/layout.{type Layout}
import sb/forms/props.{type Props}
import sb/forms/scope.{type Scope}
import sb/forms/value.{type Value}
import sb/forms/zero

const task_keys = [
  "id", "name", "category", "summary", "description", "command", "runners",
  "approvers", "layout", "summary_fields", "fields",
]

pub type Defaults {
  Defaults(category: List(String), runners: Access, approvers: Access)
}

pub type Task {
  Task(
    id: String,
    name: String,
    category: List(String),
    summary: Option(String),
    description: Option(String),
    command: List(String),
    runners: Access,
    approvers: Access,
    layout: Layout,
    fields: Dict(String, Field),
  )
}

pub fn evaluate(
  task: Task,
  scope: Scope,
  search: Dict(String, String),
  handlers: Handlers,
) -> #(Task, Scope) {
  let values = field_values(task.fields)

  let fields =
    changed_fields(scope, values)
    |> reset_changed(task.fields)
    |> evaluate_fields(values, search, handlers)

  #(Task(..task, fields:), field_values(fields))
}

fn field_values(fields: Dict(String, Field)) -> Scope {
  use scope, id, field <- dict.fold(fields, dict.new())

  field.value(field)
  |> option.map(dict.insert(scope, id, _))
  |> option.unwrap(scope)
}

fn changed_fields(a: Scope, b: Scope) -> Set(String) {
  set.from_list({
    use #(id, next) <- list.filter_map(dict.to_list(a))
    use last <- result.try(dict.get(b, id))
    use <- bool.guard(last == next, Error(Nil))
    Ok(id)
  })
}

fn reset_changed(
  refs: Set(String),
  fields: Dict(String, Field),
) -> Dict(String, Field) {
  use <- bool.guard(set.is_empty(refs), fields)
  use _id, field <- dict.map_values(fields)
  field.reset(field, refs)
}

fn evaluate_fields(
  fields: Dict(String, Field),
  scope: Scope,
  search: Dict(String, String),
  handlers: Handlers,
) -> Dict(String, Field) {
  use id, field <- dict.map_values(fields)
  let search = option.from_result(dict.get(search, id))
  field.evaluate(field, scope, search, handlers)
}

pub fn update(
  task: Task,
  id: String,
  value: Value,
) -> Result(Task, Report(Error)) {
  use field <- result.try(
    dict.get(task.fields, id)
    |> report.replace_error(error.BadId(id))
    |> result.try(field.update(_, value)),
  )

  Ok(Task(..task, fields: dict.insert(task.fields, id, field)))
}

pub fn decoder(
  defaults defaults: Defaults,
  commands commands: custom.Commands,
  filters filters: custom.Filters,
  fields fields: custom.Fields,
  sources sources: custom.Sources,
) -> Props(Task) {
  use <- state.do(props.check_keys(task_keys))

  use name <- props.get("name", decoder.from(decode.string))

  use category <- state.bind({
    case defaults.category {
      [] ->
        props.get(
          "category",
          decoder.from(decode.list(decode.string)),
          props.succeed,
        )

      _category -> props.succeed(defaults.category)
    }
  })

  use id <- props.try("id", {
    zero.lazy(make_id(category, name), decoder.from(decode.string))
  })

  use summary <- props.try("summary", {
    zero.option(decoder.from(decode.string))
  })

  use description <- props.try("description", {
    zero.option(decoder.from(decode.string))
  })

  use command <- props.try("command", {
    zero.list(decoder.from(decode.list(decode.string)))
  })

  use runners <- props.try("runners", access.decoder(fn() { defaults.runners }))
  use approvers <- props.try("approvers", {
    access.decoder(fn() { defaults.approvers })
  })

  use fields <- props.try("fields", {
    use dynamic <- zero.list
    use list <- result.map(decoder.run(dynamic, decode.list(decode.dynamic)))
    use <- return(pair.second)
    use seen, dynamic <- list.map_fold(list, set.new())
    let decoder = field.decoder(commands:, sources:, fields:, filters:)
    props.decode(dynamic, decoder)
    |> error.try_duplicate_ids(seen)
  })

  let results_layout = fn() {
    use <- return(layout.Results)
    use result <- list.map(fields)
    use #(id, _field) <- result.map(result)
    id
  }

  use layout <- props.try("layout", zero.lazy(results_layout, layout.decoder))

  props.succeed(Task(
    id:,
    name:,
    category:,
    summary:,
    description:,
    command:,
    runners:,
    approvers:,
    layout:,
    fields: dict.from_list(pair.first(result.partition(fields))),
  ))
}

const valid_id = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

fn make_id(category: List(String), name: String) -> fn() -> String {
  use <- identity
  let category = string.join(list.map(category, into_id), "-")
  string.join([category, into_id(name)], "-")
}

fn into_id(from: String) -> String {
  build_id(from, into: "")
}

fn build_id(from: String, into result: String) -> String {
  case string.pop_grapheme(from) {
    Error(Nil) -> result

    Ok(#(grapheme, rest)) -> {
      case string.contains(valid_id, grapheme) {
        True -> build_id(rest, result <> string.lowercase(grapheme))
        False -> build_id(rest, result <> "-")
      }
    }
  }
}
