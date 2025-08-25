import gleam/dict.{type Dict}
import gleam/io
import gleam/list
import gleam/option.{None}
import gleam/string
import gleam_community/ansi
import sb/access
import sb/error.{type Error}
import sb/field
import sb/handlers
import sb/inspect
import sb/kind
import sb/options
import sb/report.{type Report}
import sb/reset
import sb/scope.{type Scope}
import sb/source
import sb/task.{type Task, Task}
import sb/value

pub fn main() -> Nil {
  let strings = value.string_list(["a", "b", "c"])
  let string = value.String("str")

  let object =
    source.Literal(value.Object([#("key1", strings), #("key2", string)]))

  let radio1 = kind.Select(None, options.from_source(object))
  let radio2 = kind.Select(None, options.from_source(source.Reference("1")))
  let radio3 = kind.Select(None, options.from_source(source.Reference("2")))
  let data1 = kind.Data(reset.new(Ok(source.Reference("1")), fn(_) { ["1"] }))

  let task =
    Task(
      id: "task",
      name: "Task",
      category: ["Tests"],
      summary: None,
      description: None,
      command: [],
      runners: access.everyone(),
      approvers: access.none(),
      layout: [],
      fields: dict.from_list([
        #("1", field.new(radio1)),
        #("2", field.new(radio2)),
        #("3", field.new(radio3)),
        #("4", field.new(data1)),
      ]),
    )

  let search = dict.new()
  let handlers = handlers.empty()

  let scope = dict.new()
  let #(task, scope) = evaluate(task, scope, search, handlers)
  inspect_task(task)

  let assert Ok(task) = update(task, "1", value.String("key1"))
  let #(task, scope) = evaluate(task, scope, search, handlers)
  inspect_task(task)

  let assert Ok(task) = update(task, "2", value.String("a"))
  let #(task, scope) = evaluate(task, scope, search, handlers)
  inspect_task(task)

  let assert Ok(task) = update(task, "1", value.String("key2"))
  let #(task, _scope) = evaluate(task, scope, search, handlers)
  inspect_task(task)

  Nil
}

fn inspect_task(task: Task) {
  inspect.inspect_fields(task.fields)
  |> list.map(fn(v) { " " <> v })
  |> string.join("\n")
  |> io.println
}

fn evaluate(
  task: Task,
  scope: Scope,
  search: Dict(String, String),
  handlers: handlers.Handlers,
) -> #(Task, Dict(String, Result(value.Value, Report(Error)))) {
  let scope1 = inspect.inspect_scope(scope)
  let #(task, scope) = task.evaluate(task, scope, search, handlers)
  let scope2 = inspect.inspect_scope(scope)
  io.println(string.join([ansi.grey("eval"), scope1], " "))
  io.println(string.join([ansi.grey("eval"), scope2], " "))
  #(task, scope)
}

fn update(
  task: Task,
  id: String,
  value: value.Value,
) -> Result(Task, Report(Error)) {
  let parts = [
    ansi.grey("update"),
    ansi.green(id),
    inspect.inspect_value(value),
  ]

  io.println(string.join(parts, " "))
  task.update(task, id, value)
}
