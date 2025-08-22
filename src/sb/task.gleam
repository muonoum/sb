import gleam/bool
import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{Some}
import gleam/result
import gleam/set
import sb/error.{type Error}
import sb/field.{type Field}
import sb/scope.{type Scope}
import sb/value.{type Value}

pub type Task {
  Task(fields: Dict(String, Field))
}

pub fn evaluate(task: Task, scope: Scope) -> #(Task, Scope) {
  let values = {
    use scope, id, field <- dict.fold(task.fields, dict.new())

    field.value(field)
    |> option.map(dict.insert(scope, id, _))
    |> option.unwrap(scope)
  }

  let fields = {
    let fields = {
      use _id, field <- dict.map_values(task.fields)
      field.evaluate(field, values)
    }

    let changed =
      set.from_list({
        use #(id, evaluated) <- list.filter_map(dict.to_list(fields))
        use value <- result.try(dict.get(scope, id))
        let unchanged = Some(value) == field.value(evaluated)
        use <- bool.guard(unchanged, Error(Nil))
        Ok(id)
      })

    echo changed
    use <- bool.guard(set.is_empty(changed), fields)
    use _id, field <- dict.map_values(fields)
    field.reset(field, changed)
  }

  echo fields
  #(Task(fields:), values)
}

pub fn update(task: Task, id: String, value: Value) -> Result(Task, Error) {
  use field <- result.try(
    dict.get(task.fields, id)
    |> result.replace_error(error.BadId(id))
    |> result.try(field.update(_, value)),
  )

  Ok(Task(fields: dict.insert(task.fields, id, field)))
}
