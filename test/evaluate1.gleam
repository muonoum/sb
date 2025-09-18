import gleam/bool
import gleam/dict
import gleam/dynamic/decode
import gleam/io
import gleam/option.{Some}
import gleam/result
import gleam_community/ansi
import sb/extra/dots
import sb/extra/dynamic as dynamic_extra
import sb/extra/report
import sb/extra_server/httpc
import sb/extra_server/yaml
import sb/forms/access
import sb/forms/custom
import sb/forms/debug
import sb/forms/error
import sb/forms/handlers.{Handlers}
import sb/forms/props
import sb/forms/scope
import sb/forms/task
import sb/forms/value.{String}

pub fn main() {
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
  let scope = scope.error()
  let handlers =
    Handlers(..handlers.empty(), http: fn(request) {
      httpc.send(request, [])
      |> result.map_error(dynamic_extra.from)
      |> report.map_error(error.HttpError)
    })

  inspect(task, scope)

  let #(task, scope) = evaluate_run(task, scope, search, handlers)
  let task = update(task, "2-select", Some(String("bar")))
  let #(task, scope) = evaluate_run(task, scope, search, handlers)
  let task = update(task, "2-select", Some(String("baz")))
  let #(_task, _scope) = evaluate_run(task, scope, search, handlers)
}

pub fn inspect(task, scope) {
  debug.inspect_task(task) |> io.println
  debug.inspect_scope(scope) |> io.println
  io.println("")
}

pub fn evaluate_run(task1, scope1, search, handlers) {
  let #(task2, scope2) = task.step(task1, scope1, search, handlers)
  inspect(task2, scope2)
  use <- bool.lazy_guard(scope1 != scope2 || task1 != task2, fn() {
    evaluate_run(task2, scope2, search, handlers)
  })
  #(task2, scope2)
}

pub fn evaluate_step(task1, scope1, search, handlers) {
  let #(task2, scope2) = task.step(task1, scope1, search, handlers)
  debug.inspect_task(task2) |> io.println
  debug.inspect_scope(scope2) |> io.println
  io.println("")
  #(task2, scope2)
}

pub fn update(task, id, value) {
  io.println(
    ansi.grey("update ")
    <> debug.inspect_id(id)
    <> ansi.grey(" --> ")
    <> debug.inspect_option_value(value),
  )

  let assert Ok(task) = task.update(task, id, value)
  debug.inspect_task(task) |> io.println
  io.println("")
  task
}
