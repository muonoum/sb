import gleam/dict
import gleam/option.{None, Some}
import gleeunit/should
import helpers
import helpers/task_builder
import sb/extra/reader
import sb/extra/report
import sb/extra_server/yaml
import sb/forms/error
import sb/forms/evaluate
import sb/forms/handlers
import sb/forms/scope
import sb/forms/task
import sb/forms/value

pub fn checkbox_list_test() {
  use <- helpers.debug_task("checkbox list")

  let input =
    helpers.multi_line({
      "
      kind: tasks/v1
      category: [category]
      ---
      name: task
      fields: [{id: field, kind: checkbox, source.literal: [ichi, ni, san]}]
      "
    })

  let handlers = handlers.empty()
  let task_commands = dict.new()

  let context =
    evaluate.Context(
      scope: scope.error(),
      search: dict.new(),
      task_commands:,
      handlers:,
    )

  let task =
    task_builder.new(input, yaml.decode_string)
    |> task_builder.build
    |> should.be_ok

  helpers.field_errors(task) |> should.equal([])

  Some(value.String("ichi")) |> task.update(task, "field", _) |> should.be_error

  None |> task.update(task, "field", _) |> should.be_ok

  helpers.field_value(task, "field")
  |> reader.run(context:)
  |> should.be_some
  |> should.be_error
  |> should.equal(report.new(error.Required))

  Some(value.List([])) |> task.update(task, "field", _) |> should.be_ok

  helpers.field_value(task, "field")
  |> reader.run(context:)
  |> should.be_some
  |> should.be_error
  |> should.equal(report.new(error.Required))

  let task =
    Some(value.List([value.String("ichi")]))
    |> task.update(task, "field", _)
    |> should.be_ok

  helpers.field_value(task, "field")
  |> reader.run(context:)
  |> should.be_some
  |> should.be_ok
  |> should.equal(value.List([value.String("ichi")]))

  let task =
    Some(value.List([value.String("ichi"), value.String("san")]))
    |> task.update(task, "field", _)
    |> should.be_ok

  helpers.field_value(task, "field")
  |> reader.run(context:)
  |> should.be_some
  |> should.be_ok
  |> should.equal(value.List([value.String("ichi"), value.String("san")]))

  task
}

pub fn checkbox_pairs_test() {
  use <- helpers.debug_task("checkbox pairs")

  let input =
    helpers.multi_line({
      "
      kind: tasks/v1
      category: [category]
      ---
      name: task
      fields: [{id: field, kind: checkbox, source.literal: [ichi: en, ni, san: tre]}]
      "
    })

  let handlers = handlers.empty()
  let task_commands = dict.new()

  let context =
    evaluate.Context(
      scope: scope.error(),
      search: dict.new(),
      task_commands:,
      handlers:,
    )

  let task =
    task_builder.new(input, yaml.decode_string)
    |> task_builder.build
    |> should.be_ok

  helpers.field_errors(task) |> should.equal([])

  Some(value.String("ichi")) |> task.update(task, "field", _) |> should.be_error

  Some(value.List([value.String("en")]))
  |> task.update(task, "field", _)
  |> should.be_error

  None |> task.update(task, "field", _) |> should.be_ok

  helpers.field_value(task, "field")
  |> reader.run(context:)
  |> should.be_some
  |> should.be_error
  |> should.equal(report.new(error.Required))

  Some(value.List([])) |> task.update(task, "field", _) |> should.be_ok

  helpers.field_value(task, "field")
  |> reader.run(context:)
  |> should.be_some
  |> should.be_error
  |> should.equal(report.new(error.Required))

  let task =
    Some(value.List([value.String("ichi")]))
    |> task.update(task, "field", _)
    |> should.be_ok

  helpers.field_value(task, "field")
  |> reader.run(context:)
  |> should.be_some
  |> should.be_ok
  |> should.equal(value.List([value.String("en")]))

  let task =
    Some(value.List([value.String("ichi"), value.String("san")]))
    |> task.update(task, "field", _)
    |> should.be_ok

  helpers.field_value(task, "field")
  |> reader.run(context:)
  |> should.be_some
  |> should.be_ok
  |> should.equal(value.List([value.String("en"), value.String("tre")]))

  task
}

pub fn checkbox_object_test() {
  use <- helpers.debug_task("checkbox object")

  let input =
    helpers.multi_line({
      "
      kind: tasks/v1
      category: [category]
      ---
      name: task
      fields: [{id: field, kind: checkbox, source.literal: {ichi: en, ni: to, san: tre}}]
      "
    })

  let handlers = handlers.empty()
  let task_commands = dict.new()

  let context =
    evaluate.Context(
      scope: scope.error(),
      search: dict.new(),
      task_commands:,
      handlers:,
    )

  let task =
    task_builder.new(input, yaml.decode_string)
    |> task_builder.build
    |> should.be_ok

  helpers.field_errors(task) |> should.equal([])

  Some(value.String("ichi")) |> task.update(task, "field", _) |> should.be_error
  Some(value.List([value.String("en")]))
  |> task.update(task, "field", _)
  |> should.be_error

  None |> task.update(task, "field", _) |> should.be_ok

  helpers.field_value(task, "field")
  |> reader.run(context:)
  |> should.be_some
  |> should.be_error
  |> should.equal(report.new(error.Required))

  Some(value.List([])) |> task.update(task, "field", _) |> should.be_ok

  helpers.field_value(task, "field")
  |> reader.run(context:)
  |> should.be_some
  |> should.be_error
  |> should.equal(report.new(error.Required))

  let task =
    Some(value.List([value.String("ichi")]))
    |> task.update(task, "field", _)
    |> should.be_ok

  helpers.field_value(task, "field")
  |> reader.run(context:)
  |> should.be_some
  |> should.be_ok
  |> should.equal(value.List([value.String("en")]))

  let task =
    Some(value.List([value.String("ichi"), value.String("san")]))
    |> task.update(task, "field", _)
    |> should.be_ok

  helpers.field_value(task, "field")
  |> reader.run(context:)
  |> should.be_some
  |> should.be_ok
  |> should.equal(value.List([value.String("en"), value.String("tre")]))

  task
}

pub fn select_list_value_test() {
  use <- helpers.debug_task("select list value")

  let input =
    helpers.multi_line({
      "
      kind: tasks/v1
      category: [category]
      ---
      name: task
      fields: [{id: field, kind: select, source.literal: [[foo, 20, false, 3.14]]}]
      "
    })

  let task =
    task_builder.new(input, yaml.decode_string)
    |> task_builder.build
    |> should.be_ok

  helpers.field_errors(task) |> should.equal([])

  value.List([
    value.String("foo"),
    value.Int(20),
    value.Bool(False),
    value.Float(3.14),
  ])
  |> Some
  |> task.update(task, "field", _)
  |> should.be_ok
}

pub fn select_duplicate_test() {
  let input =
    helpers.multi_line({
      "
      kind: tasks/v1
      category: [category]
      ---
      name: task
      fields:
        - {id: a, kind: checkbox, source.literal: [10]}
      "
    })

  let task =
    task_builder.new(input, yaml.decode_string)
    |> task_builder.build
    |> should.be_ok

  helpers.field_errors(task) |> should.equal([])

  Some(value.List([value.Int(10), value.Int(10)]))
  |> task.update(task, "a", _)
  |> should.be_error
}

pub fn defaults_test() {
  use <- helpers.debug_task("defaults")

  let input =
    helpers.multi_line({
      "
      kind: tasks/v1
      category: [category]
      ---
      name: task
      fields:
        - {id: ok1, kind: checkbox, default: [10], source.literal: [10, 20, 30]}
        - {id: ok2, kind: radio, default: 10, source.literal: [10, 20, 30]}
        - {id: ok3, kind: checkbox, default: [a], source.literal: [a: 10, 20, 30]}
        - {id: error1, kind: checkbox, default: 10, source.literal: [10, 20, 30]}
        - {id: error2, kind: radio, default: [10], source.literal: [10, 20, 30]}
      "
    })

  let handlers = handlers.empty()
  let task_commands = dict.new()

  let context =
    evaluate.Context(
      scope: scope.error(),
      search: dict.new(),
      task_commands:,
      handlers:,
    )

  let task =
    task_builder.new(input, yaml.decode_string)
    |> task_builder.build
    |> should.be_ok

  let assert [_, _] = helpers.field_errors(task)

  helpers.field_value(task, "ok1")
  |> reader.run(context:)
  |> should.be_some
  |> should.be_ok
  |> should.equal(value.List([value.Int(10)]))

  helpers.field_value(task, "ok2")
  |> reader.run(context:)
  |> should.be_some
  |> should.be_ok
  |> should.equal(value.Int(10))

  helpers.field_value(task, "ok3")
  |> reader.run(context:)
  |> should.be_some
  |> should.be_ok
  |> should.equal(value.List([value.Int(10)]))

  let task =
    Some(value.List([value.Int(10)]))
    |> task.update(task, "ok1", _)
    |> should.be_ok

  helpers.field_value(task, "ok1")
  |> reader.run(context:)
  |> should.be_some
  |> should.be_ok
  |> should.equal(value.List([value.Int(10)]))

  let task =
    Some(value.Int(10))
    |> task.update(task, "ok2", _)
    |> should.be_ok

  helpers.field_value(task, "ok2")
  |> reader.run(context:)
  |> should.be_some
  |> should.be_ok
  |> should.equal(value.Int(10))

  task
}
