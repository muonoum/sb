import gleeunit/should
import helpers
import helpers/task_builder
import sb/extra/report
import sb/extra_server/yaml
import sb/forms/error

pub fn unknown_keys_test() {
  let input =
    helpers.multi_line({
      "
      kind: tasks/v1
      category: [category]
      ---
      bad1: key
      name: task-name
      bad2: key
      "
    })

  task_builder.new(input, yaml.decode_string)
  |> task_builder.build
  |> should.be_error
  |> should.equal(report.new(error.UnknownKeys(["bad1", "bad2"])))
}

pub fn missing_category_test() {
  let input =
    helpers.multi_line({
      "
      kind: tasks/v1
      ---
      name: task-name
      "
    })

  task_builder.new(input, yaml.decode_string)
  |> task_builder.build
  |> should.be_error
  |> should.equal(report.new(error.MissingProperty("category")))
}

pub fn default_category_test() {
  let input =
    helpers.multi_line({
      "
      kind: tasks/v1
      category: [default-category]
      ---
      name: task-name
      "
    })

  let task =
    task_builder.new(input, yaml.decode_string)
    |> task_builder.build
    |> should.be_ok

  task.category
  |> should.equal(["default-category"])
}

pub fn task_category_overrides_default_category_test() {
  let input =
    helpers.multi_line({
      "
      kind: tasks/v1
      category: [default-category]
      ---
      name: task-name
      category: [task-category]
      "
    })

  let task =
    task_builder.new(input, yaml.decode_string)
    |> task_builder.build
    |> should.be_ok

  task.category
  |> should.equal(["task-category"])
}
