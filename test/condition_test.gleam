import gleam/dict
import gleam/option.{Some}
import gleeunit/should
import helpers
import helpers/task_builder
import sb/extra/reader
import sb/extra/report
import sb/extra_server/yaml
import sb/forms/condition
import sb/forms/error
import sb/forms/evaluate
import sb/forms/handlers
import sb/forms/scope
import sb/forms/task
import sb/forms/value

pub fn condition_test() {
  let base_context =
    evaluate.Context(
      scope: scope.error(),
      search: dict.new(),
      task_commands: dict.new(),
      handlers: handlers.empty(),
    )

  // scope={} | a==10
  let condition = condition.Equal("a", value.Int(10))
  let scope = scope.error()
  evaluate.Context(..base_context, scope:)
  |> reader.run(condition.evaluate(condition), context: _)
  |> should.equal(condition.Equal("a", value.Int(10)))

  // scope={a=10} | a==20
  let condition = condition.Equal("a", value.Int(20))
  let scope = scope.put(scope.error(), "a", Ok(value.Int(10)))
  evaluate.Context(..base_context, scope:)
  |> reader.run(condition.evaluate(condition), context: _)
  |> should.equal(condition.Resolved(False))

  // scope={} | a!=10
  let condition = condition.NotEqual("a", value.Int(10))
  let scope = scope.error()
  evaluate.Context(..base_context, scope:)
  |> reader.run(condition.evaluate(condition), context: _)
  |> should.equal(condition.NotEqual("a", value.Int(10)))

  // scope={a=10} | a!=20
  let condition = condition.Equal("a", value.Int(20))
  let scope = scope.put(scope.error(), "a", Ok(value.Int(10)))
  evaluate.Context(..base_context, scope:)
  |> reader.run(condition.evaluate(condition), context: _)
  |> should.equal(condition.Resolved(False))
}

pub fn optional_test() {
  use <- helpers.debug_task("optional")

  let source =
    helpers.multi_line({
      "
      kind: tasks/v1
      category: [category]
      ---
      name: task
      fields:
        - {id: required, kind: text}
        - {id: optional, optional: true, kind: text}
      "
    })

  let handlers = handlers.empty()
  let task_commands = dict.new()

  let task =
    task_builder.new(source, yaml.decode_string)
    |> task_builder.build
    |> should.be_ok

  helpers.field_errors(task) |> should.equal([])

  let context =
    evaluate.Context(
      scope: scope.error(),
      search: dict.new(),
      task_commands:,
      handlers:,
    )

  helpers.field_value(task, "optional")
  |> reader.run(context:)
  |> should.be_none

  helpers.field_value(task, "required")
  |> reader.run(context:)
  |> should.be_some
  |> should.be_error
  |> should.equal(report.new(error.Required))

  let task =
    task.update(task, "required", Some(value.String("string")))
    |> should.be_ok

  helpers.field_value(task, "required")
  |> reader.run(context:)
  |> should.be_some
  |> should.be_ok

  task
}
