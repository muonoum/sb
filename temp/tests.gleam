import birdie
import gleam/dict
import gleam/dynamic/decode
import gleam/option.{None}
import gleeunit
import gleeunit/should
import pprint
import sb/access
import sb/dots
import sb/field
import sb/handlers
import sb/inspect
import sb/kind
import sb/options
import sb/report
import sb/source
import sb/task.{type Task, Task}
import sb/value.{type Value}
import sb/yaml

fn field_value(task: Task, id: String) -> Value {
  task.values(task)
  |> dict.get(id)
  |> should.be_ok
  |> should.be_ok
}

pub fn reference_reset_test() {
  let handlers = handlers.empty()
  let search = dict.new()
  let task = load_task("test_data/task1.yaml")

  let scope = dict.new()
  let #(task, scope) = task.evaluate(task, scope, search, handlers)

  let task = task.update(task, "a", value.String("a")) |> should.be_ok
  let #(task, scope) = task.evaluate(task, scope, search, handlers)

  field_value(task, "a")
  |> should.equal(value.String("a"))

  field_value(task, "b")
  |> should.equal(value.String("a"))

  let task = task.update(task, "a", value.String("b")) |> should.be_ok
  let #(task, scope) = task.evaluate(task, scope, search, handlers)

  field_value(task, "a")
  |> should.equal(value.String("b"))

  field_value(task, "b")
  |> should.equal(value.String("b"))
}

pub fn select_field_update_test() {
  let strings = source.Literal(value.string_list(["a", "b", "c"]))
  let field = kind.select(options.from_source(strings))

  let task =
    Task(
      id: "task",
      name: "Task",
      category: ["Tests"],
      summary: None,
      description: option.None,
      command: [],
      runners: access.everyone(),
      approvers: access.none(),
      layout: [],
      fields: dict.from_list([#("1", field.new(field))]),
    )

  let search = dict.new()
  let handlers = handlers.empty()

  let scope = dict.new()
  let #(task, _scope) = task.evaluate(task, scope, search, handlers)

  task.update(task, "1", value.String("a"))
  |> should.be_ok

  task.update(task, "1", value.String("x"))
  |> should.be_error
  |> report.issue
  |> pprint.format
  |> birdie.snap(title: "select_update_with_bad_key")

  task.update(task, "1", value.Null)
  |> should.be_error
  |> report.issue
  |> pprint.format
  |> birdie.snap(title: "select_update_with_bad_value_type")
}

pub fn multi_select_field_update_test() {
  let strings = source.Literal(value.string_list(["a", "b", "c"]))
  let field = kind.multi_select(options.from_source(strings))

  let task =
    Task(
      id: "task",
      name: "Task",
      category: ["Tests"],
      summary: None,
      description: option.None,
      command: [],
      runners: access.everyone(),
      approvers: access.none(),
      layout: [],
      fields: dict.from_list([#("1", field.new(field))]),
    )

  let search = dict.new()
  let handlers = handlers.empty()

  let scope = dict.new()
  let #(task, _scope) = task.evaluate(task, scope, search, handlers)

  task.update(task, "1", value.List([value.String("a")]))
  |> should.be_ok

  task.update(
    task,
    "1",
    value.List([value.String("a"), value.String("b"), value.String("c")]),
  )
  |> should.be_ok

  task.update(task, "1", value.List([value.String("x")]))
  |> should.be_error
  |> report.issue
  |> pprint.format
  |> birdie.snap(title: "multi_select_update_with_bad_key")

  task.update(task, "1", value.String("a"))
  |> should.be_error
  |> report.issue
  |> pprint.format
  |> birdie.snap(title: "multi_select_update_with_bad_single_value")

  task.update(task, "1", value.Null)
  |> should.be_error
  |> report.issue
  |> pprint.format
  |> birdie.snap(title: "multi_select_update_with_bad_value_type")
}
