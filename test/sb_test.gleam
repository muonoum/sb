import birdie
import gleam/dict
import gleam/option.{Some}
import gleam/string
import gleeunit
import gleeunit/should
import helpers
import sb/forms/debug
import sb/forms/handlers
import sb/forms/scope
import sb/forms/task
import sb/forms/value.{String}

pub fn main() -> Nil {
  gleeunit.main()
}

const single_data_literal = "
name: single data literal
fields:
  - {id: data, kind: data, source.literal: value}
"

const select_with_reference_to_data = "
name: Select with reference to data
fields:
  - {id: data, kind: data, source.literal: [a, b, c]}
  - {id: select, kind: select, source.reference: data}
"

pub fn evaluate_single_data_literal_test() {
  let task = helpers.decode_task(single_data_literal) |> should.be_ok
  helpers.field_errors(task) |> should.equal([])

  let handlers = handlers.empty()
  let scope = scope.error()
  let search = dict.new()

  task.step(task, scope, search:, handlers:)
  string.join([debug.task(task), debug.scope(scope)], "\n")
  |> birdie.snap("evaluate--task-single-data-literal")
}

pub fn evaluate_select_with_reference_to_data_test() {
  let task = helpers.decode_task(select_with_reference_to_data) |> should.be_ok
  helpers.field_errors(task) |> should.equal([])
  let handlers = handlers.empty()
  let scope = scope.error()
  let search = dict.new()

  let #(task, scope) = task.step(task, scope, search:, handlers:)
  string.join([debug.task(task), debug.scope(scope)], "\n")
  |> birdie.snap("evaluate--select-with-reference-to-data--step1")

  let #(task, scope) = task.step(task, scope, search:, handlers:)
  string.join([debug.task(task), debug.scope(scope)], "\n")
  |> birdie.snap("evaluate--select-with-reference-to-data--step2")

  let task = task.update(task, "select", Some(String("a"))) |> should.be_ok
  let #(task, scope) = task.step(task, scope, search:, handlers:)
  string.join([debug.task(task), debug.scope(scope)], "\n")
  |> birdie.snap("evaluate--select-with-reference-to-data--step3")

  let task = task.update(task, "select", Some(String("b"))) |> should.be_ok
  let #(task, scope) = task.step(task, scope, search:, handlers:)
  string.join([debug.task(task), debug.scope(scope)], "\n")
  |> birdie.snap("evaluate--select-with-reference-to-data--step4")
}
