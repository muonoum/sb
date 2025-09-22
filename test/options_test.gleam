import gleam/option.{None, Some}
import gleeunit/should
import helpers.{strings}
import sb/forms/task
import sb/forms/value

pub fn checkbox_list_test() {
  let source =
    "
    name: checkbox_list_source
    fields: [{id: field, kind: checkbox, source.literal: [ichi, ni, san]}]
    "

  let task = helpers.decode_task(source) |> should.be_ok
  helpers.field_errors(task) |> should.equal([])

  task.update(task, "field", Some(value.String("ichi"))) |> should.be_error
  task.update(task, "field", None) |> should.be_ok
  task.update(task, "field", Some(value.List([]))) |> should.be_ok

  let task = task.update(task, "field", Some(strings(["ichi"]))) |> should.be_ok
  let task =
    task.update(task, "field", Some(strings(["ichi", "san"]))) |> should.be_ok

  helpers.debug_task(task, True)
}

pub fn checkbox_pairs_test() {
  let source =
    "
    name: checkbox_list_source
    fields: [{id: field, kind: checkbox, source.literal: [ichi: en, ni: to, san: tre]}]
    "

  let task = helpers.decode_task(source) |> should.be_ok
  helpers.field_errors(task) |> should.equal([])

  task.update(task, "field", Some(value.String("ichi"))) |> should.be_error
  task.update(task, "field", None) |> should.be_ok
  task.update(task, "field", Some(value.List([]))) |> should.be_ok
  task.update(task, "field", Some(strings(["en"]))) |> should.be_error

  let task = task.update(task, "field", Some(strings(["ichi"]))) |> should.be_ok
  let task =
    task.update(task, "field", Some(strings(["ichi", "san"]))) |> should.be_ok

  helpers.debug_task(task, True)
}

pub fn options_test() {
  let source =
    "
    name: options
    fields:
      - {id: list, kind: checkbox, source.literal: [ichi, ni, san]}
      - {id: pairs, kind: checkbox, source.literal: [ichi: en, ni: to, san: tre]}
      - {id: object, kind: checkbox, source.literal: {ichi: en, ni: to, san: tre}}
      - {id: values, kind: checkbox, source.literal: [10: integer, true: boolean,  [1, 2, 3]: list]}
      - {id: mixed, kind: checkbox, source.literal: [ichi: en,  ni, san, 10: integer, 1.2: float]}
    "

  let task = helpers.decode_task(source) |> should.be_ok
  helpers.field_errors(task) |> should.equal([])

  let value = value.List([value.String("ichi")])
  let task = task.update(task, "list", Some(value)) |> should.be_ok
  let task = task.update(task, "pairs", Some(value)) |> should.be_ok
  let task = task.update(task, "object", Some(value)) |> should.be_ok
  let task = task.update(task, "mixed", Some(value)) |> should.be_ok

  let value =
    value.List([
      value.Bool(True),
      value.List([value.Int(1), value.Int(2), value.Int(3)]),
    ])

  let task = task.update(task, "values", Some(value)) |> should.be_ok

  helpers.debug_task(task, False)
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

const defaults = "
name: defaults
fields:
  - {id: ok1, kind: checkbox, default: [10], source.literal: [10, 20, 30]}
  - {id: ok2, kind: radio, default: 10, source.literal: [10, 20, 30]}
  - {id: ok3, kind: checkbox, default: [a], source.literal: [a: 10, 20, 30]}
  - {id: error1, kind: checkbox, default: 10, source.literal: [10, 20, 30]}
  - {id: error2, kind: radio, default: [10], source.literal: [10, 20, 30]}
"

pub fn defaults_test() {
  let task = helpers.decode_task(defaults) |> should.be_ok
  let assert [_, _] = helpers.field_errors(task)

  let task =
    task.update(task, "ok1", Some(value.List([value.Int(10)])))
    |> should.be_ok

  let task =
    task.update(task, "ok2", Some(value.Int(10)))
    |> should.be_ok

  helpers.debug_task(task, False)
}
