import birdie
import gleam/dict
import gleam/list
import gleam/result
import gleam/string
import gleeunit/should
import helpers
import helpers/task_builder
import sb/extra_server/yaml
import sb/forms/debug
import sb/forms/handlers
import sb/forms/scope
import sb/forms/task

fn custom_sources() -> String {
  helpers.multi_line({
    "
    kind: sources/v1
    ---
    id: lorem
    literal:
      - Lorem ipsum dolor sit amet
      - Curabitur pretium metus
      - Vestibulum vitae arcu eu mauris
    ---
    id: echo
    fetch:
      method: post
      url: /mock/echo
    ---
    id: custom-echo
    echo:
      method: get
      url: /mock/lorem/sentences/3/3
    ---
    id: custom-lorem
    kind: lorem
    ---
    id: kind
    literal: [10, 20, 30]
    "
  })
}

pub fn data_custom_source_test() {
  let input =
    helpers.multi_line({
      "
      kind: tasks/v1
      category: [category]
      ---
      name: task
      fields:
        - {id: field1, kind: data, source: lorem}
        - {id: field2, kind: data, source.echo: {body.literal: [a, b, c]}}
      "
    })

  let task =
    task_builder.new(input, yaml.decode_string)
    |> task_builder.load_custom_sources(custom_sources(), yaml.decode_string)
    |> should.be_ok
    |> task_builder.build
    |> should.be_ok

  helpers.field_errors(task) |> should.equal([])

  helpers.field_sources(task, "field1")
  |> result.all
  |> should.be_ok
  |> list.map(debug.format_source)
  |> string.join("\n")
  |> birdie.snap("custom-source--literal-source")

  helpers.field_sources(task, "field2")
  |> result.all
  |> should.be_ok
  |> list.map(debug.format_source)
  |> string.join("\n")
  |> birdie.snap("custom-source--fetch-source")
}

pub fn radio_custom_source_test() {
  let input =
    helpers.multi_line({
      "
      kind: tasks/v1
      category: [category]
      ---
      name: task
      fields:
        - {id: field1, kind: radio, source: lorem}
        - {id: field2, kind: radio, source.echo: {body.literal: [a, b, c]}}

        - id: field3
          kind: radio
          source.groups:
            - {label: a, source.literal: [a, b, c]}
            - {label: b, source: lorem}
            - {label: c, source.echo: {body: lorem}}

        - id: field4
          kind: radio
          source.custom-echo:
            - {label: a, source.literal: [a, b, c]}

        - {id: field5, kind: radio, source: custom-echo}
        - {id: field6, kind: radio, source: custom-lorem}
        - {id: field7, kind: radio, source: kind}
      "
    })

  let task =
    task_builder.new(input, yaml.decode_string)
    |> task_builder.load_custom_sources(custom_sources(), yaml.decode_string)
    |> should.be_ok
    |> task_builder.build
    |> should.be_ok

  helpers.field_errors(task) |> should.equal([])

  let handlers =
    handlers.Handlers(
      command: handlers.empty_command(),
      http: helpers.http_handler,
    )

  let scope = scope.error()
  let search = dict.new()

  let #(task, _scope) = task.evaluate(task, scope, search:, handlers:)

  helpers.field_sources(task, "field1") |> result.all |> should.be_ok
  helpers.field_sources(task, "field2") |> result.all |> should.be_ok

  helpers.field_sources(task, "field3")
  |> result.all
  |> should.be_ok
  |> list.map(debug.format_source)
  |> string.join("\n")
  |> birdie.snap("source-groups")

  helpers.field_sources(task, "field4") |> result.all |> should.be_error
  helpers.field_sources(task, "field5") |> result.all |> should.be_ok
  helpers.field_sources(task, "field6") |> result.all |> should.be_ok
  helpers.field_sources(task, "field7") |> result.all |> should.be_ok
}
