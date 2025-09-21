import gleam/dict
import gleam/io
import gleam/option.{Some}
import gleeunit/should
import helpers
import sb/forms/debug
import sb/forms/handlers
import sb/forms/scope
import sb/forms/task
import sb/forms/value
import sb/store

pub fn options_test() {
  let store = helpers.start_store_with_no_errors()

  let task =
    store.get_task(store, "test-options")
    |> should.be_ok

  helpers.field_errors(task)
  |> should.equal([])

  let handlers = handlers.empty()
  let scope = scope.error()
  let search = dict.new()

  let #(task, _scope) = helpers.run_evaluate(task, scope, search, handlers)

  task.update(
    task,
    "checkbox-object-options",
    Some(value.List([value.String("ichi")])),
  )
  |> should.be_ok

  let task =
    task.update(
      task,
      "checkbox-mixed-options",
      Some(
        value.List([
          // TODO: Duplikater -> error.DuplicateKey
          value.String("ichi"),
          value.String("ichi"),
          value.String("ni"),
          value.String("san"),
        ]),
      ),
    )
    |> should.be_ok

  // id: checkbox-mixed-options
  //   kind: checkbox
  //   options: [ichi=en ni san]
  //   value: [ichi=en ichi=en ni san]

  io.println("")
  debug.task(task) |> io.println
}
