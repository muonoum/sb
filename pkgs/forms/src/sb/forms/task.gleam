import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option}
import gleam/pair
import gleam/result
import gleam/set.{type Set}
import gleam/string
import sb/extra/function.{compose, identity, return}
import sb/extra/reader.{type Reader}
import sb/extra/report.{type Report}
import sb/extra/state
import sb/forms/access.{type Access}
import sb/forms/command.{type Command}
import sb/forms/custom
import sb/forms/decoder
import sb/forms/error.{type Error}
import sb/forms/evaluate
import sb/forms/field.{type Field}
import sb/forms/layout.{type Layout}
import sb/forms/props
import sb/forms/scope.{type Scope}
import sb/forms/value.{type Value}
import sb/forms/zero

const task_keys = [
  "id", "name", "category", "summary", "description", "command", "runners",
  "approvers", "notify", "layout", "summary_fields", "fields",
]

pub type Context {
  Context(
    category: List(String),
    runners: Access,
    approvers: Access,
    commands: Dict(String, Command),
    filters: custom.Filters,
  )
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
    commands: Dict(String, Command),
  )
}

pub fn step(task: Task) -> Reader(#(Task, Scope), evaluate.Context) {
  use scope1 <- reader.bind(evaluate.get_scope())
  use fields <- reader.bind(evaluate_fields(task.fields))
  use scope2 <- reader.bind(field_values(fields))
  let changed = changed_refs(scope1, scope2)
  let fields = reset_changed(fields, changed)
  reader.return(#(Task(..task, fields:), scope2))
}

pub fn evaluate(task1: Task) -> Reader(#(Task, Scope), evaluate.Context) {
  use scope1 <- reader.bind(evaluate.get_scope())
  use #(task2, scope2) <- reader.bind(step(task1))
  let changed = scope1 != scope2 || task1 != task2
  use <- bool.guard(!changed, reader.return(#(task1, scope1)))
  evaluate.with_scope(evaluate(task2), scope2)
}

fn evaluate_fields(
  fields: Dict(String, Field),
) -> Reader(Dict(String, Field), evaluate.Context) {
  use <- return(compose(reader.sequence, reader.map(_, dict.from_list)))
  use #(id, field) <- list.map(dict.to_list(fields))
  use search <- reader.bind(evaluate.get_search(id))
  use field <- reader.bind(field.evaluate(field, search))
  reader.return(#(id, field))
}

// TODO: Fjern behov for reader/context
fn field_values(fields: Dict(String, Field)) -> Reader(Scope, evaluate.Context) {
  use scope, id, field <- dict.fold(fields, reader.return(scope.ok()))
  use value <- reader.bind(field.value(field))
  use scope <- reader.bind(scope)

  option.map(value, scope.put(scope, id, _))
  |> option.unwrap(scope)
  |> reader.return
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
  context context: Context,
  filters filters: custom.Filters,
  fields fields: custom.Fields,
  sources sources: custom.Sources,
) -> props.Try(Task) {
  use <- state.try_do(props.check_keys(task_keys))

  use name <- props.get("name", decoder.from(decode.string))

  use category <- props.try("category", {
    use <- zero.try(_, decoder.from(decode.list(decode.string)))
    use <- bool.guard(context.category == [], Error(Nil))
    Ok(context.category)
  })

  use id <- props.try("id", {
    zero.ok(make_id(category, name), decoder.from(decode.string))
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

  use runners <- props.try("runners", access.decoder(context.runners))
  use approvers <- props.try("approvers", access.decoder(context.approvers))

  use fields <- props.try("fields", {
    use dynamic <- zero.list
    use list <- result.map(decoder.run(dynamic, decode.list(decode.dynamic)))
    use <- return(pair.second)
    use seen, dynamic <- list.map_fold(list, set.new())

    let filters =
      custom.Filters(case filters, context.filters {
        custom.Filters(a), custom.Filters(b) -> dict.merge(a, b)
      })

    let decoder = field.decoder(sources:, fields:, filters:)
    props.decode(dynamic, decoder) |> try_unique_id(seen)
  })

  let results = list.map(fields, result.map(_, pair.first))
  let fields = dict.from_list(pair.first(result.partition(fields)))
  use layout <- props.try("layout", layout.decoder(results))

  state.ok(Task(
    id:,
    name:,
    category:,
    summary:,
    description:,
    command:,
    runners:,
    approvers:,
    layout:,
    fields:,
    commands: context.commands,
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
  let build_id = build_id(_, into: "")
  let category = string.join(list.map(category, build_id), "-")
  string.join([category, build_id(name)], "-")
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
