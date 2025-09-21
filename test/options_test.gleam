import gleam/io
import gleam/option.{Some}
import gleeunit/should
import helpers
import sb/forms/debug
import sb/forms/task
import sb/forms/value

const task1 = "
name: options
fields:
  - {id: list, kind: checkbox, source.literal: [ichi, ni, san]}
  - {id: pairs, kind: checkbox, source.literal: [ichi: en, ni: to, san: tre]}
  - {id: object, kind: checkbox, source.literal: {ichi: en, ni: to, san: tre}}
  - {id: values, kind: checkbox, source.literal: [10: integer, true: boolean,  [1, 2, 3]: list]}
  - {id: mixed, kind: checkbox, source.literal: [ichi: en,  ni, san, 10: integer, 1.2: float]}
"

pub fn options_test() {
  let task =
    helpers.decode_task(task1, task.default_category(["test"])) |> should.be_ok
  helpers.field_errors(task) |> should.equal([])

  let selection = Some(value.List([value.String("ichi")]))
  let task = task.update(task, "list", selection) |> should.be_ok
  let task = task.update(task, "pairs", selection) |> should.be_ok
  let task = task.update(task, "object", selection) |> should.be_ok
  let task = task.update(task, "mixed", selection) |> should.be_ok

  let task =
    task.update(
      task,
      "values",
      Some(
        value.List([
          value.Bool(True),
          value.List([value.Int(1), value.Int(2), value.Int(3)]),
        ]),
      ),
    )
    |> should.be_ok

  io.println("")
  debug.task(task)
  |> io.println
}
// pub fn update_duplicate_test() {
//   let task =
//     helpers.decode_task(task1, task.default_category(["Test"])) |> should.be_ok
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
