import gleam/dict
import gleam/option.{None, Some}
import gleam/result
import gleeunit/should
import helpers
import sb/forms/field
import sb/forms/task
import sb/forms/value

pub fn select_list_value_test() {
  use <- helpers.debug_task()

  let source =
    helpers.lines([
      "name: task",
      "fields: [{id: field, kind: select, source.literal: [[foo, 20, false, 3.14]]}]",
    ])

  let task = helpers.decode_task(source) |> should.be_ok
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

pub fn checkbox_pairs_test() {
  use <- helpers.debug_task()

  let source =
    helpers.lines([
      "name: task",
      "fields: [{id: field, kind: checkbox, source.literal: [ichi: en, ni, san: tre]}]",
    ])

  let task = helpers.decode_task(source) |> should.be_ok
  helpers.field_errors(task) |> should.equal([])

  Some(value.String("ichi")) |> task.update(task, "field", _) |> should.be_error
  Some(value.List([value.String("en")]))
  |> task.update(task, "field", _)
  |> should.be_error

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
  task.update(task, "field", Some(value.List([value.String("en")])))
  |> should.be_error

  task.update(task, "field", None) |> should.be_ok
  task.update(task, "field", Some(value.List([]))) |> should.be_ok

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

// pub fn select_duplicate_test() {
//   let source =
//     helpers.lines([
//       "name: task", "fields:", "- {id: a, kind: checkbox, source.literal: [10]}",
//     ])

//   let task = helpers.decode_task(source) |> should.be_ok
//   helpers.field_errors(task) |> should.equal([])

//   Some(value.List([value.Int(10), value.Int(10)]))
//   |> task.update(task, "a", _)
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

  dict.get(task.fields, "ok1")
  |> result.map(field.value)
  |> should.be_ok
  |> should.equal(Some(Ok(value.List([value.Int(10)]))))

  dict.get(task.fields, "ok2")
  |> result.map(field.value)
  |> should.be_ok
  |> should.equal(Some(Ok(value.Int(10))))

  dict.get(task.fields, "ok3")
  |> result.map(field.value)
  |> should.be_ok
  |> should.equal(Some(Ok(value.List([value.Int(10)]))))

  let task =
    Some(value.List([value.Int(10)]))
    |> task.update(task, "ok1", _)
    |> should.be_ok

  Some(value.Int(10))
  |> task.update(task, "ok2", _)
  |> should.be_ok
}
