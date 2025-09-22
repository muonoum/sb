import gleam/option.{None, Some}
import gleeunit/should
import helpers
import sb/forms/task
import sb/forms/value

pub fn checkbox_list_test() {
  use <- helpers.debug_task()

  let source =
    helpers.lines([
      "name: task",
      "fields: [{id: field, kind: checkbox, source.literal: [ichi, ni, san]}]",
    ])

  let task = helpers.decode_task(source) |> should.be_ok
  helpers.field_errors(task) |> should.equal([])

  Some(value.String("ichi")) |> task.update(task, "field", _) |> should.be_error
  None |> task.update(task, "field", _) |> should.be_ok
  Some(value.List([])) |> task.update(task, "field", _) |> should.be_ok

  let task =
    Some(value.List([value.String("ichi")]))
    |> task.update(task, "field", _)
    |> should.be_ok

  Some(value.List([value.String("ichi"), value.String("san")]))
  |> task.update(task, "field", _)
  |> should.be_ok
}

pub fn checkbox_pair_test() {
  use <- helpers.debug_task()

  let source =
    helpers.lines([
      "name: task",
      "fields: [{id: field, kind: checkbox, source.literal: [ichi: en, ni, san: tre]}]",
    ])

  let task = helpers.decode_task(source) |> should.be_ok
  helpers.field_errors(task) |> should.equal([])

  Some(value.String("ichi")) |> task.update(task, "field", _) |> should.be_error
  None |> task.update(task, "field", _) |> should.be_ok
  Some(value.List([])) |> task.update(task, "field", _) |> should.be_ok
  Some(value.List([value.String("en")]))
  |> task.update(task, "field", _)
  |> should.be_error

  let task =
    Some(value.List([value.String("ichi")]))
    |> task.update(task, "field", _)
    |> should.be_ok

  Some(value.List([value.String("ichi"), value.String("san")]))
  |> task.update(task, "field", _)
  |> should.be_ok
}

pub fn checkbox_object_test() {
  use <- helpers.debug_task()

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
    Some(value.List([value.String("ichi")]))
    |> task.update(task, "field", _)
    |> should.be_ok

  Some(value.List([value.String("ichi"), value.String("san")]))
  |> task.update(task, "field", _)
  |> should.be_ok
}

pub fn options_values_test() {
  use <- helpers.debug_task()

  let source =
    helpers.lines([
      "name: task",
      "fields:",
      "- {id: a, kind: checkbox, source.literal: [10: integer, true: boolean, [1, 2, 3]: list]}",
      "- {id: b, kind: select, multiple: true, source.literal: [10: integer, true: boolean, [1, 2, 3]: list]}",
      "- {id: c, kind: radio, source.literal: [10: integer, true: boolean, [1, 2, 3]: list]}",
      "- {id: d, kind: select, source.literal: [10: integer, true: boolean, [1, 2, 3]: list]}",
    ])

  let task = helpers.decode_task(source) |> should.be_ok
  helpers.field_errors(task) |> should.equal([])

  let bool_value = value.Bool(True)
  let integer_value = value.Int(10)
  let integer_list_value =
    value.List([value.Int(1), value.Int(2), value.Int(3)])
  let list_value = value.List([bool_value, integer_list_value])

  let task = Some(list_value) |> task.update(task, "a", _) |> should.be_ok
  let task = Some(list_value) |> task.update(task, "b", _) |> should.be_ok
  let task = Some(bool_value) |> task.update(task, "c", _) |> should.be_ok
  Some(integer_value) |> task.update(task, "d", _) |> should.be_ok
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
  use <- helpers.debug_task()

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
    Some(value.List([value.Int(10)]))
    |> task.update(task, "ok1", _)
    |> should.be_ok

  Some(value.Int(10))
  |> task.update(task, "ok2", _)
  |> should.be_ok
}
