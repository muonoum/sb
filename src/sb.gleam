import gleam/dict
import gleam/io
import gleam/option.{None}
import gleam_community/ansi
import sb/error.{type Error}
import sb/field
import sb/inspect
import sb/kind
import sb/options
import sb/source
import sb/task.{type Task, Task}
import sb/value

pub fn main() -> Nil {
  let strings =
    value.List([value.String("a"), value.String("b"), value.String("c")])
  let string = value.String("str")
  let object = source.Literal(value.Object([#("en", strings), #("to", string)]))

  let radio1 = kind.Radio(None, options.from_source(object))
  let radio2 = kind.Radio(None, options.from_source(source.Reference("1")))
  // let checkbox1 = kind.Checkbox([], options.from_source(object))
  // let checkbox2 = kind.Checkbox([], options.from_source(source.Reference("1")))

  let task =
    Task(
      dict.from_list([
        #("1", field.new(radio1)),
        #("2", field.new(radio2)),
        // #("1", field.new(checkbox1)),
      // #("2", field.new(checkbox2)),
      ]),
    )

  let scope = dict.new()
  let #(task, scope) = task.evaluate(task, scope)
  inspect.task(task)

  let assert Ok(task) = update(task, "1", value.String("en"))
  // let assert Ok(task) = update(task, "1", value.List([value.String("en")]))
  let #(task, scope) = task.evaluate(task, scope)
  inspect.task(task)

  let assert Ok(task) = update(task, "2", value.String("a"))
  // let assert Ok(task) = update(task, "2", value.List([strings]))
  let #(task, scope) = task.evaluate(task, scope)
  inspect.task(task)

  let assert Ok(task) = update(task, "1", value.String("to"))
  // let assert Ok(task) = update(task, "1", value.List([value.String("to")]))
  let #(task, scope) = task.evaluate(task, scope)
  inspect.task(task)

  Nil
}

fn update(task: Task, id: String, value: value.Value) -> Result(Task, Error) {
  io.println(
    ansi.grey("==> ") <> id <> " select " <> inspect.inspect_value(value),
  )
  task.update(task, id, value)
}
