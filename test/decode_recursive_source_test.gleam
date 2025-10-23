import gleeunit/should
import helpers
import helpers/task_builder
import sb/extra/report
import sb/extra_server/yaml
import sb/forms/error

fn custom_fields() -> String {
  helpers.multi_line({
    "
    kind: fields/v1
    ---
    id: recursive
    kind: recursive
    "
  })
}

pub fn recursive_field_test() {
  let input =
    helpers.multi_line({
      "
      kind: tasks/v1
      category: [category]
      ---
      name: task
      fields: [{id: field, kind: recursive}]
      "
    })

  let task =
    task_builder.new(input, yaml.decode_string)
    |> task_builder.load_custom_fields(custom_fields(), yaml.decode_string)
    |> should.be_ok
    |> task_builder.build()
    |> should.be_ok

  let assert [report] = helpers.field_errors(task)

  report.issue(report)
  |> should.equal(error.FieldContext("field"))

  report.get_context(report)
  |> should.equal([
    error.Recursive("recursive"),
  ])
}

fn custom_sources() {
  helpers.multi_line({
    "
    kind: sources/v1
    ---
    id: recursive1
    fetch: {url: http://example.org, body: recursive1}
    ---
    id: recursive2
    kind: recursive2
    ---
    id: recursive3
    command: {command: hei, stdin: recursive3}
    "
  })
}

pub fn recursive_source_test() {
  let recursive_source1 = "source: recursive1"
  let recursive_source2 = "source: recursive2"
  let recursive_source3 = "source: recursive3"

  let sources =
    helpers.load_custom_sources(custom_sources(), yaml.decode_string)
    |> should.be_ok

  let assert Ok([dynamic, ..]) =
    helpers.load_documents(recursive_source1, yaml.decode_string)

  let report =
    helpers.decode_source_property(dynamic, "source", sources:)
    |> should.be_error

  report.issue(report)
  |> should.equal(error.BadProperty("source"))

  report.get_context(report)
  |> should.equal([
    error.BadKind("fetch"),
    error.BadProperty("body"),
    error.Recursive("recursive1"),
  ])

  let assert Ok([dynamic, ..]) =
    helpers.load_documents(recursive_source2, yaml.decode_string)

  let report =
    helpers.decode_source_property(dynamic, "source", sources:)
    |> should.be_error

  report.issue(report)
  |> should.equal(error.BadProperty("source"))

  report.get_context(report)
  |> should.equal([
    error.Recursive("recursive2"),
  ])

  let assert Ok([dynamic, ..]) =
    helpers.load_documents(recursive_source3, yaml.decode_string)

  let report =
    helpers.decode_source_property(dynamic, "source", sources:)
    |> should.be_error

  report.issue(report)
  |> should.equal(error.BadProperty("source"))

  report.get_context(report)
  |> should.equal([
    error.BadKind("command"),
    error.BadProperty("stdin"),
    error.Recursive("recursive3"),
  ])
}

fn custom_filters() -> String {
  helpers.multi_line({
    "
    kind: filters/v1
    ---
    id: recursive
    kind: recursive
    "
  })
}

pub fn recursive_filter_test() {
  let input =
    helpers.multi_line({
      "
      kind: tasks/v1
      category: [category]
      ---
      name: task
      fields:
      - id: field
        kind: data
        source.literal: null
        filters: [{kind: recursive}]
      "
    })

  let task =
    task_builder.new(input, yaml.decode_string)
    |> task_builder.load_custom_filters(custom_filters(), yaml.decode_string)
    |> should.be_ok
    |> task_builder.build
    |> should.be_ok

  let assert [report] = helpers.field_errors(task)

  report.issue(report)
  |> should.equal(error.FieldContext("field"))

  report.get_context(report)
  |> should.equal([
    error.BadProperty("filters"),
    error.Recursive("recursive"),
  ])
}
