import gleam/bool
import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/result
import gleam/set.{type Set}
import sb/error.{type Error}
import sb/field.{type Field}
import sb/handlers.{type Handlers}
import sb/report.{type Report}
import sb/scope.{type Scope}
import sb/value.{type Value}

pub type Task {
  Task(fields: Dict(String, Field))
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

  #(Task(fields:), field_values(fields))
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

  Ok(Task(fields: dict.insert(task.fields, id, field)))
}
