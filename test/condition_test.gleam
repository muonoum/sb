import gleam/option.{Some}
import gleeunit/should
import helpers
import helpers/task_builder
import sb/extra/report
import sb/extra_server/yaml
import sb/forms/condition
import sb/forms/error
import sb/forms/handlers
import sb/forms/scope
import sb/forms/task
import sb/forms/value

pub fn condition_test() {
  // scope={} | a==10
  condition.Equal("a", value.Int(10))
  |> condition.evaluate(scope.error())
  |> should.equal(condition.Equal("a", value.Int(10)))

  // scope={a=10} | a==20
  condition.Equal("a", value.Int(20))
  |> condition.evaluate(scope.put(scope.error(), "a", Ok(value.Int(10))))
  |> should.equal(condition.Resolved(False))

  // scope={} | a!=10
  condition.NotEqual("a", value.Int(10))
  |> condition.evaluate(scope.error())
  |> should.equal(condition.NotEqual("a", value.Int(10)))

  // scope={a=10} | a!=20
  condition.Equal("a", value.Int(20))
  |> condition.evaluate(scope.put(scope.error(), "a", Ok(value.Int(10))))
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

  let task =
    task_builder.new(source, yaml.decode_string)
    |> task_builder.build
    |> should.be_ok

  helpers.field_errors(task) |> should.equal([])

  helpers.field_value(task, "optional", handlers:) |> should.be_none

  helpers.error_field_value(task, "required", handlers:)
  |> should.equal(report.new(error.Required))

  let task =
    task.update(task, "required", Some(value.String("string")))
    |> should.be_ok

  helpers.field_value(task, "required", handlers:)
  |> should.be_some
  |> should.be_ok

  task
}
