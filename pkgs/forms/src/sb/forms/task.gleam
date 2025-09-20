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
import sb/extra/try_state as state
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
  "approvers", "notify", "layout", "summary_fields", "fields",
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

pub fn step(
  task: Task,
  scope1: Scope,
  search search: Dict(String, String),
  handlers handlers: Handlers,
) -> #(Task, Scope) {
  let fields = evaluate_fields(task.fields, scope1, search, handlers)
  let scope2 = field_scope(fields)
  let changed = changed_refs(scope1, scope2)
  let fields = reset_changed(fields, changed)
  #(Task(..task, fields:), scope2)
}

fn evaluate_fields(
  fields: Dict(String, Field),
  scope: Scope,
  search: Dict(String, String),
  handlers: Handlers,
) -> Dict(String, Field) {
  use id, field <- dict.map_values(fields)
  let search = option.from_result(dict.get(search, id))
  field.evaluate(field, scope, search:, handlers:)
}

fn field_scope(fields: Dict(String, Field)) -> Scope {
  use scope, id, field <- dict.fold(fields, scope.ok())

  field.value(field)
  |> option.map(scope.put(scope, id, _))
  |> option.unwrap(scope)
}

fn changed_refs(scope1: Scope, scope2: Scope) -> Set(String) {
  use <- return(set.from_list)
  use #(id, next) <- list.filter_map(scope.to_list(scope1))
  use last <- result.try(scope.get(scope2, id))
  use <- bool.guard(last == next, Error(Nil))
  Ok(id)
}

fn reset_changed(
  fields: Dict(String, Field),
  refs: Set(String),
) -> Dict(String, Field) {
  use <- bool.guard(set.is_empty(refs), fields)
  use _id, field <- dict.map_values(fields)
  field.reset(field, refs)
}

pub fn update(
  task: Task,
  id: String,
  value: Option(Value),
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
  filters filters: custom.Filters,
  fields fields: custom.Fields,
  sources sources: custom.Sources,
) -> Props(Task) {
  use <- state.do(props.check_keys(task_keys))

  use name <- props.get("name", decoder.from(decode.string))

  use category <- state.bind({
    use <- bool.guard(defaults.category != [], props.succeed(defaults.category))

    props.get(
      "category",
      decoder.from(decode.list(decode.string)),
      props.succeed,
    )
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

  use runners <- props.try("runners", access.decoder(defaults.runners))
  use approvers <- props.try("approvers", { access.decoder(defaults.approvers) })

  use fields <- props.try("fields", {
    use dynamic <- zero.list
    use list <- result.map(decoder.run(dynamic, decode.list(decode.dynamic)))
    use <- return(pair.second)
    use seen, dynamic <- list.map_fold(list, set.new())
    let decoder = field.decoder(sources:, fields:, filters:)
    props.decode(dynamic, decoder)
    |> try_unique_id(seen)
  })

  let results = list.map(fields, result.map(_, pair.first))
  use layout <- props.try("layout", layout.decoder(results))

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

fn try_unique_id(
  result: Result(#(String, v), Report(Error)),
  seen: Set(String),
) -> #(Set(String), Result(#(String, v), Report(Error))) {
  case result {
    Error(report) -> #(seen, Error(report))

    Ok(#(id, field)) ->
      case set.contains(seen, id) {
        True -> #(seen, report.error(error.DuplicateId(id)))
        False -> #(set.insert(seen, id), Ok(#(id, field)))
      }
  }
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
