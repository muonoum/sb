import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/io
import gleam/list
import gleam/string
import gleam_community/ansi
import inspect
import sb/extra/dots
import sb/extra/report.{type Report}
import sb/extra/yaml
import sb/forms/access
import sb/forms/custom
import sb/forms/error.{type Error}
import sb/forms/handlers
import sb/forms/props
import sb/forms/scope.{type Scope}
import sb/forms/task.{type Task}
import sb/forms/value

pub fn main() -> Nil {
  let assert Ok(task) = {
    let assert Ok(dynamic) = yaml.decode_file("test_data/task2.yaml")
    let assert Ok([doc, ..]) = decode.run(dynamic, decode.list(decode.dynamic))

    dots.split(doc)
    |> props.decode(task.decoder(
      filters: custom.Filters(dict.new()),
      fields: custom.Fields(dict.new()),
      sources: custom.Sources(dict.new()),
      defaults: task.Defaults(
        category: [],
        runners: access.none(),
        approvers: access.none(),
      ),
    ))
  }

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
