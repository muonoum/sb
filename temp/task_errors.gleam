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

pub fn decoder(dynamic: Dynamic, fields, filters) -> Result(Task, Report(Error)) {
  use dict <- result.try(
    decode.run(dynamic, decode.dict(decode.string, decode.dynamic))
    |> report.map_error(error.DecodeError)
    |> result.try(error.unknown_keys(_, [task_keys])),
  )

  let name = case dict.get(dict, "name") {
    Error(Nil) -> error.missing_property("name")

    Ok(dynamic) ->
      decode.run(dynamic, decode.string)
      |> error.bad_property("name")
  }

  let category = case dict.get(dict, "category") {
    Error(Nil) -> error.missing_property("category")

    Ok(dynamic) ->
      decode.run(dynamic, decode.list(decode.string))
      |> error.bad_property("category")
  }

  let id = case dict.get(dict, "id") {
    Error(Nil) -> {
      use name <- result.try(name)
      use category <- result.map(category)
      let category = string.join(list.map(category, into_id), "-")
      string.join([category, into_id(name)], "-")
    }

    Ok(dynamic) ->
      decode.run(dynamic, decode.string)
      |> error.bad_property("id")
  }

  let summary = case dict.get(dict, "summary") {
    Error(Nil) -> Ok(None)

    Ok(dynamic) ->
      decode.run(dynamic, decode.string)
      |> error.bad_property("summary")
      |> result.map(Some)
  }

  let description = case dict.get(dict, "description") {
    Error(Nil) -> Ok(None)

    Ok(dynamic) ->
      decode.run(dynamic, decode.string)
      |> error.bad_property("description")
      |> result.map(Some)
  }

  let command = case dict.get(dict, "command") {
    Error(Nil) -> Ok([])

    Ok(dynamic) ->
      decode.run(dynamic, decode.list(decode.string))
      |> error.bad_property("command")
  }

  let runners = case dict.get(dict, "runners") {
    Error(Nil) -> Ok(access.none())

    Ok(dynamic) ->
      access.decoder(dynamic)
      |> report.error_context(error.BadProperty("runners"))
  }

  let approvers = case dict.get(dict, "approvers") {
    Error(Nil) -> Ok(access.none())

    Ok(dynamic) ->
      access.decoder(dynamic)
      |> report.error_context(error.BadProperty("approvers"))
  }

  let field_results = case dict.get(dict, "fields") {
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

        Ok(#(id, field)) -> {
          use <- bool.lazy_guard(set.contains(seen, id), fn() {
            #(seen, report.error(error.DuplicateId(id)))
          })

          #(set.insert(seen, id), Ok(#(id, field)))
        }
      }
    }
  }

  let errors = []
  let #(name, errors) = try(errors, name, zero: "")
  let #(category, errors) = try(errors, category, zero: [])
  let #(id, errors) = try(errors, id, zero: "")
  let #(summary, errors) = try(errors, summary, zero: None)
  let #(description, errors) = try(errors, description, zero: None)
  let #(command, errors) = try(errors, command, zero: [])
  let #(runners, errors) = try(errors, runners, zero: access.none())
  let #(approvers, errors) = try(errors, approvers, zero: access.none())
  let #(field_results, errors) = try(errors, field_results, zero: [])

  case errors {
    [] ->
      Ok(Task(
        id:,
        name:,
        category:,
        summary:,
        description:,
        command:,
        runners:,
        approvers:,
        fields: dict.from_list({
          result.partition(field_results)
          |> pair.first
        }),
      ))

    errors -> report.error(error.Errors(list.reverse(list.unique(errors))))
  }
}

fn try(errors: List(e), value: Result(v, e), zero zero: v) -> #(v, List(e)) {
  case value {
    Error(report) -> #(zero, [report, ..errors])
    Ok(value) -> #(value, errors)
  }
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
