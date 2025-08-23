import gleam/dict
import gleam/io
import gleam/option.{None}
import gleam/string
import gleam_community/ansi
import sb/error.{type Error}
import sb/field
import sb/inspect
import sb/kind
import sb/options
import sb/report.{type Report}
import sb/source
import sb/task.{type Task, Task}
import sb/value

pub fn main() -> Nil {
  let strings =
    value.List([value.String("a"), value.String("b"), value.String("c")])

  let string = value.String("str")
  let object = source.Literal(value.Object([#("en", strings), #("to", string)]))

  let radio1 = kind.Select(None, options.from_source(object))
  let radio2 = kind.Select(None, options.from_source(source.Reference("1")))
  let radio3 = kind.Select(None, options.from_source(source.Reference("2")))
  // let checkbox1 = kind.Checkbox([], options.from_source(object))
  // let checkbox2 = kind.Checkbox([], options.from_source(source.Reference("1")))

  let task =
    Task(
      dict.from_list([
        #("1", field.new(radio1)),
        #("2", field.new(radio2)),
        #("3", field.new(radio3)),
        // #("1", field.new(checkbox1)),
      // #("2", field.new(checkbox2)),
      ]),
    )

  let scope = dict.new()
  let #(task, scope) = evaluate(task, scope)
  inspect.task(task)
  // inspect.scope(scope)

  let assert Ok(task) = update(task, "1", value.String("en"))
  // let assert Ok(task) = update(task, "1", value.List([value.String("en")]))
  let #(task, scope) = evaluate(task, scope)
  inspect.task(task)
  // inspect.scope(scope)

  let assert Ok(task) = update(task, "2", value.String("a"))
  // let assert Ok(task) = update(task, "2", value.List([strings]))
  let #(task, scope) = evaluate(task, scope)
  inspect.task(task)

  let assert Ok(task) = update(task, "1", value.String("to"))
  // let assert Ok(task) = update(task, "1", value.List([value.String("to")]))
  let #(task, scope) = evaluate(task, scope)
  inspect.task(task)

  Nil
}

fn evaluate(task, scope) {
  let scope1 = inspect.inspect_scope(scope)
  let #(task, scope) = task.evaluate(task, scope)
  let scope2 = inspect.inspect_scope(scope)
  io.println(string.join([ansi.grey("ev~"), scope1], " "))
  io.println(string.join([ansi.grey("ev="), scope2], " "))
  #(task, scope)
}

fn update(
  task: Task,
  id: String,
  value: value.Value,
) -> Result(Task, Report(Error)) {
  let parts = [
    ansi.grey("upd"),
    ansi.green(id),
    inspect.inspect_value(value),
  ]

  io.println(string.join(parts, " "))
  task.update(task, id, value)
}
