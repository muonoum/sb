import gleam/bit_array
import gleam/dict
import gleam/http/response
import gleam/json
import gleam/list
import gleam/option.{Some}
import gleeunit/should
import helpers
import helpers/task_builder
import sb/extra/reader
import sb/extra/reset
import sb/extra_server/yaml
import sb/forms/evaluate
import sb/forms/field
import sb/forms/handlers
import sb/forms/kind
import sb/forms/scope
import sb/forms/task
import sb/forms/value

pub fn loading_propagation_test() {
  let input =
    helpers.multi_line({
      "
      kind: tasks/v1
      category: [category]
      ---
      name: task
      fields:
      - {id: fetch1, kind: data, source.fetch: http://example.org}
      - {id: select1, kind: select, multiple: true, source.reference: fetch1}
      - {id: select2, kind: select, multiple: true, source.reference: select1}
      - id: fetch2
        kind: data
        source.fetch:
          url: http://example.org
          method: post
          body.reference: select2
      - {id: select3, kind: select, multiple: true, source.reference: fetch2}
      - {id: data, kind: data, source.reference: select3}
      "
    })

  let task =
    task_builder.new(input, yaml.decode_string)
    |> task_builder.build
    |> should.be_ok

  helpers.field_errors(task) |> should.equal([])

  let handlers =
    handlers.Handlers(..handlers.empty(), http: fn(_request, _timeout) {
      let data =
        json.array(["a", "b", "c"], json.string)
        |> json.to_string
        |> bit_array.from_string

      response.new(200)
      |> response.set_body(data)
      |> Ok
    })

  let task_commands = dict.new()
  let scope = scope.error()
  let search = dict.new()
  let context = evaluate.Context(scope:, search:, task_commands:, handlers:)

  let #(task, _scope) = reader.run(context:, reader: task.step(task))

  let loading = {
    use id, field <- dict.map_values(task.fields)
    use source <- list.any(kind.sources(field.kind))
    let source = reset.unwrap(source) |> should.be_ok
    field.is_loading(id, source, task.fields)
  }

  dict.get(loading, "fetch1") |> should.equal(Ok(True))
  dict.get(loading, "select1") |> should.equal(Ok(True))
  dict.get(loading, "select2") |> should.equal(Ok(False))
  dict.get(loading, "fetch2") |> should.equal(Ok(False))
  dict.get(loading, "select3") |> should.equal(Ok(False))
  dict.get(loading, "data") |> should.equal(Ok(False))

  let #(task, scope) = reader.run(context:, reader: task.step(task))

  let #(task, scope) =
    task.step(task)
    |> evaluate.with_scope(scope)
    |> reader.run(context:)

  let task =
    Some(value.List([value.String("a")]))
    |> task.update(task, "select1", _)
    |> should.be_ok

  let #(task, scope) =
    task.step(task) |> evaluate.with_scope(scope) |> reader.run(context:)
  let #(task, _scope) =
    task.step(task) |> evaluate.with_scope(scope) |> reader.run(context:)

  Some(value.List([value.String("a")]))
  |> task.update(task, "select2", _)
  |> should.be_ok
}
