import gleam/option.{None, Some}
import gleeunit/should
import helpers
import sb/forms/task
import sb/forms/value

pub fn checkbox_list_test() {
  let source =
    helpers.lines([
      "name: task",
      "fields: [{id: field, kind: checkbox, source.literal: [ichi, ni, san]}]",
    ])

  let task = helpers.decode_task(source) |> should.be_ok
  helpers.field_errors(task) |> should.equal([])

  task.update(task, "field", Some(value.String("ichi"))) |> should.be_error
  task.update(task, "field", None) |> should.be_ok
  task.update(task, "field", Some(value.List([]))) |> should.be_ok

  let task =
    task.update(task, "field", Some(value.List([value.String("ichi")])))
    |> should.be_ok

  let task =
    task.update(
      task,
      "field",
      Some(value.List([value.String("ichi"), value.String("san")])),
    )
    |> should.be_ok

  helpers.debug_task(task, True)
}

pub fn checkbox_pair_test() {
  let source =
    helpers.lines([
      "name: task",
      "fields: [{id: field, kind: checkbox, source.literal: [ichi: en, ni, san: tre]}]",
    ])

  let task = helpers.decode_task(source) |> should.be_ok
  helpers.field_errors(task) |> should.equal([])

  task.update(task, "field", Some(value.String("ichi"))) |> should.be_error
  task.update(task, "field", None) |> should.be_ok
  task.update(task, "field", Some(value.List([]))) |> should.be_ok
  task.update(task, "field", Some(value.List([value.String("en")])))
  |> should.be_error

  let task =
    task.update(task, "field", Some(value.List([value.String("ichi")])))
    |> should.be_ok

  let task =
    task.update(
      task,
      "field",
      Some(value.List([value.String("ichi"), value.String("san")])),
    )
    |> should.be_ok

  helpers.debug_task(task, True)
}

pub fn checkbox_object_test() {
  let source =
    helpers.lines([
      "name: task",
      "fields: [{id: field, kind: checkbox, source.literal: {ichi: en, ni: to, san: tre}}]",
    ])

  let task = helpers.decode_task(source) |> should.be_ok
  helpers.field_errors(task) |> should.equal([])

  task.update(task, "field", Some(value.String("ichi"))) |> should.be_error
  task.update(task, "field", None) |> should.be_ok
  task.update(task, "field", Some(value.List([]))) |> should.be_ok
  task.update(task, "field", Some(value.List([value.String("en")])))
  |> should.be_error

  let task =
    task.update(task, "field", Some(value.List([value.String("ichi")])))
    |> should.be_ok

  let task =
    task.update(
      task,
      "field",
      Some(value.List([value.String("ichi"), value.String("san")])),
    )
    |> should.be_ok

  helpers.debug_task(task, True)
}

pub fn checkbox_values_test() {
  let source =
    helpers.lines([
      "name: task",
      "fields: [{id: field, kind: checkbox, source.literal: [10: integer, true: boolean, [1, 2, 3]: list]}]",
    ])

  let task = helpers.decode_task(source) |> should.be_ok
  helpers.field_errors(task) |> should.equal([])

  let value =
    value.List([
      value.Bool(True),
      value.List([value.Int(1), value.Int(2), value.Int(3)]),
    ])

  let task = task.update(task, "field", Some(value)) |> should.be_ok

  helpers.debug_task(task, True)
}

// pub fn update_duplicate_test() {
//   let task = helpers.decode_task(task1) |> should.be_ok
//   helpers.field_errors(task) |> should.equal([])

//   task.update(
//     task,
//     "values",
//     Some(
//       value.List([
//         value.Int(10),
//         value.Int(10),
//       ]),
//     ),
//   )
//   |> should.be_error
// }

pub fn defaults_test() {
  let source =
    helpers.lines([
      "name: task",
      "fields:",
      "- {id: ok1, kind: checkbox, default: [10], source.literal: [10, 20, 30]}",
      "- {id: ok2, kind: radio, default: 10, source.literal: [10, 20, 30]}",
      "- {id: ok3, kind: checkbox, default: [a], source.literal: [a: 10, 20, 30]}",
      "- {id: error1, kind: checkbox, default: 10, source.literal: [10, 20, 30]}",
      "- {id: error2, kind: radio, default: [10], source.literal: [10, 20, 30]}",
    ])

  let task = helpers.decode_task(source) |> should.be_ok
  let assert [_, _] = helpers.field_errors(task)

  let task =
    task.update(task, "ok1", Some(value.List([value.Int(10)])))
    |> should.be_ok

  let task =
    task.update(task, "ok2", Some(value.Int(10)))
    |> should.be_ok

  helpers.debug_task(task, False)
}
