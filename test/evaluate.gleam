import gleam/dict
import gleam/dynamic/decode
import gleam/io
import gleam/option.{Some}
import gleam/result
import gleam/string
import inspect
import sb/extra/dots
import sb/extra/dynamic as dynamic_extra
import sb/extra/httpc
import sb/extra/report
import sb/extra/yaml
import sb/forms/access
import sb/forms/custom
import sb/forms/debug
import sb/forms/error
import sb/forms/handlers.{Handlers}
import sb/forms/props
import sb/forms/task
import sb/forms/value.{String}

pub fn main() {
  let assert Ok(task) = {
    let assert Ok(dynamic) = yaml.decode_file("test_data/task5.yaml")
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
  let handlers =
    Handlers(..handlers.empty(), http: fn(request) {
      httpc.send(request, [])
      |> result.map_error(dynamic_extra.from)
      |> report.map_error(error.HttpError)
    })

  let scope = dict.new()

  let #(task, scope) = evaluate_step(task, scope, search, handlers)
  let #(task, scope) = evaluate_step(task, scope, search, handlers)
}

pub fn evaluate_step(task, scope, search, handlers) {
  io.println("evaluate")
  let #(task, scope2) = task.evaluate(task, scope, search, handlers)
  debug.inspect_task(task) |> io.println
  debug.inspect_scope(scope2) |> io.println
  io.println("")
  #(task, scope2)
}

pub fn update(task, id, value) {
  io.println("update " <> id <> " --> " <> string.inspect(value))
  let assert Ok(task) = task.update(task, id, value)
  inspect.inspect_task(task) |> io.println
  io.println("")
  task
}
