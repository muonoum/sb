import extra
import extra/state
import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pair
import gleam/result
import gleam/set.{type Set}
import gleam/string
import sb/access.{type Access}
import sb/custom
import sb/decoder
import sb/error.{type Error}
import sb/field.{type Field}
import sb/handlers.{type Handlers}
import sb/props.{type Props}
import sb/report.{type Report}
import sb/scope.{type Scope}
import sb/value.{type Value}

const task_keys = [
  "id", "name", "category", "summary", "description", "command", "runners",
  "approvers", "layout", "summary_fields", "fields",
]

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
    layout: List(Result(String, Report(Error))),
    fields: Dict(String, Field),
  )
}

pub fn values(task: Task) -> Scope {
  field_values(task.fields)
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

pub fn decoder(fields: custom.Fields, filters: custom.Filters) -> Props(Task) {
  use <- state.do(props.check_keys(task_keys))

  use name <- props.field("name", decoder.new(decode.string))

  use category <- props.field("category", {
    decoder.new(decode.list(decode.string))
  })

  use id <- props.default_field("id", make_id(category, name), {
    decoder.new(decode.string)
  })

  use summary <- props.default_field("summary", Ok(None), {
    decoder.new(decode.map(decode.string, Some))
  })

  use description <- props.default_field("description", Ok(None), {
    decoder.new(decode.map(decode.string, Some))
  })

  use command <- props.default_field("command", Ok([]), {
    decoder.new(decode.list(decode.string))
  })

  use runners <- props.default_field("runners", Ok(access.none()), {
    props.decode(_, access.decoder())
  })

  use approvers <- props.default_field("approvers", Ok(access.none()), {
    props.decode(_, access.decoder())
  })

  use fields <- props.default_field("fields", Ok([]), fn(dynamic) {
    use list <- result.map(decoder.run(dynamic, decode.list(decode.dynamic)))
    use <- extra.return(pair.second)
    use seen, dynamic <- list.map_fold(list, set.new())
    props.decode(dynamic, field.decoder(fields, filters))
    |> error.try_duplicate_ids(seen)
  })

  props.succeed(Task(
    id:,
    name:,
    category:,
    summary:,
    description:,
    command:,
    runners:,
    approvers:,
    layout: list.map(fields, result.map(_, pair.first)),
    fields: dict.from_list(pair.first(result.partition(fields))),
  ))
}

const valid_id = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

fn make_id(category, name) {
  let category = string.join(list.map(category, into_id), "-")
  Ok(string.join([category, into_id(name)], "-"))
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
