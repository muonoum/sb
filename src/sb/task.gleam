import gleam/bool
import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/result
import gleam/set.{type Set}
import sb/error.{type Error}
import sb/field.{type Field}
import sb/report.{type Report}
import sb/scope.{type Scope}
import sb/value.{type Value}

pub type Task {
  Task(fields: Dict(String, Field))
}

pub fn evaluate(task: Task, scope: Scope) -> #(Task, Scope) {
  // let values = {
  //   use scope, id, field <- dict.fold(task.fields, dict.new())

  //   field.value(field)
  //   |> option.map(dict.insert(scope, id, _))
  //   |> option.unwrap(scope)
  // }

  // let changed =
  //   set.from_list({
  //     use #(id, next) <- list.filter_map(dict.to_list(values))
  //     use last <- result.try(dict.get(scope, id))
  //     use <- bool.guard(last == next, Error(Nil))
  //     Ok(id)
  //   })

  // let fields = {
  //   use <- bool.guard(set.is_empty(changed), task.fields)
  //   use _id, field <- dict.map_values(task.fields)
  //   field.reset(field, changed)
  // }

  // let fields = {
  //   use _id, field <- dict.map_values(fields)
  //   field.evaluate(field, values)
  // }

  // let values = {
  //   use scope, id, field <- dict.fold(fields, dict.new())

  //   field.value(field)
  //   |> option.map(dict.insert(scope, id, _))
  //   |> option.unwrap(scope)
  // }

  // #(Task(fields:), values)

  let next_scope = get_scope(task.fields)

  let fields =
    changed_fields(scope, next_scope)
    |> reset_changed(task.fields, _)
    |> evaluate_fields(next_scope)

  #(Task(fields:), get_scope(fields))
}

fn get_scope(fields: Dict(String, Field)) -> Scope {
  use scope, id, field <- dict.fold(fields, dict.new())

  field.value(field)
  |> option.map(dict.insert(scope, id, _))
  |> option.unwrap(scope)
}

fn changed_fields(scope1: Scope, scope2: Scope) -> Set(String) {
  set.from_list({
    use #(id, next) <- list.filter_map(dict.to_list(scope1))
    use last <- result.try(dict.get(scope2, id))
    use <- bool.guard(last == next, Error(Nil))
    Ok(id)
  })
}

fn reset_changed(
  fields: Dict(String, Field),
  changed: Set(String),
) -> Dict(String, Field) {
  use <- bool.guard(set.is_empty(changed), fields)
  use _id, field <- dict.map_values(fields)
  field.reset(field, changed)
}

fn evaluate_fields(
  fields: Dict(String, Field),
  scope: Scope,
) -> Dict(String, Field) {
  use _id, field <- dict.map_values(fields)
  field.evaluate(field, scope)
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
