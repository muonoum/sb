import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pair
import gleam/result
import gleam/set.{type Set}
import gleam/string
import sb/access.{type Access}
import sb/do
import sb/error.{type Error}
import sb/extra
import sb/field.{type Field}
import sb/handlers.{type Handlers}
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

pub fn decoder(
  dynamic: Dynamic,
  fields: Dict(String, Dict(String, Dynamic)),
  filters: Dict(String, Dict(String, Dynamic)),
) -> Result(Task, Report(Error)) {
  use <- do.run

  use dict <- do.require(
    decode.run(dynamic, decode.dict(decode.string, decode.dynamic))
    |> report.map_error(error.DecodeError)
    |> result.try(error.unknown_keys(_, [task_keys])),
  )

  use name <- do.try(zero: "", value: {
    case dict.get(dict, "name") {
      Error(Nil) -> error.missing_property("name")

      Ok(dynamic) ->
        decode.run(dynamic, decode.string)
        |> error.bad_property("name")
    }
  })

  use category <- do.try(zero: [], value: {
    case dict.get(dict, "category") {
      Error(Nil) -> error.missing_property("category")

      Ok(dynamic) ->
        decode.run(dynamic, decode.list(decode.string))
        |> error.bad_property("category")
    }
  })

  use id <- do.try(zero: "", value: {
    case dict.get(dict, "id") {
      Error(Nil) -> {
        let category = string.join(list.map(category, into_id), "-")
        Ok(string.join([category, into_id(name)], "-"))
      }

      Ok(dynamic) ->
        decode.run(dynamic, decode.string)
        |> error.bad_property("id")
    }
  })

  use summary <- do.try(zero: None, value: {
    case dict.get(dict, "summary") {
      Error(Nil) -> Ok(None)

      Ok(dynamic) ->
        decode.run(dynamic, decode.string)
        |> error.bad_property("summary")
        |> result.map(Some)
    }
  })

  use description <- do.try(zero: None, value: {
    case dict.get(dict, "description") {
      Error(Nil) -> Ok(None)

      Ok(dynamic) ->
        decode.run(dynamic, decode.string)
        |> error.bad_property("description")
        |> result.map(Some)
    }
  })

  use command <- do.try(zero: [], value: {
    case dict.get(dict, "command") {
      Error(Nil) -> Ok([])

      Ok(dynamic) ->
        decode.run(dynamic, decode.list(decode.string))
        |> error.bad_property("command")
    }
  })

  use runners <- do.try(zero: access.none(), value: {
    case dict.get(dict, "runners") {
      Error(Nil) -> Ok(access.none())

      Ok(dynamic) ->
        access.decoder(dynamic)
        |> report.error_context(error.BadProperty("runners"))
    }
  })

  use approvers <- do.try(zero: access.none(), value: {
    case dict.get(dict, "approvers") {
      Error(Nil) -> Ok(access.none())

      Ok(dynamic) ->
        access.decoder(dynamic)
        |> report.error_context(error.BadProperty("approvers"))
    }
  })

  use field_results <- do.try(zero: [], value: {
    case dict.get(dict, "fields") {
      Error(Nil) -> Ok([])

      Ok(dynamic) -> {
        use list <- result.map(
          decode.run(dynamic, decode.list(decode.dynamic))
          |> error.bad_property("fields"),
        )

        use <- extra.return(pair.second)
        use seen, dynamic <- list.map_fold(list, set.new())
        case field.decoder(dynamic, fields, filters) {
          Error(report) -> #(seen, Error(report))

          Ok(#(id, field)) ->
            case set.contains(seen, id) {
              True -> #(seen, report.error(error.DuplicateId(id)))
              False -> #(set.insert(seen, id), Ok(#(id, field)))
            }
        }
      }
    }
  })

  do.succeed(Task(
    id:,
    name:,
    category:,
    summary:,
    description:,
    command:,
    runners:,
    approvers:,
    layout: {
      use result <- list.map(field_results)
      use #(id, _field) <- result.map(result)
      id
    },
    fields: dict.from_list({
      result.partition(field_results)
      |> pair.first
    }),
  ))
}

const valid_id = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

fn into_id(from: String) {
  build_id(from, into: "")
}

fn build_id(from: String, into result: String) {
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
