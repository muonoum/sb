import gleeunit/should
import helpers
import helpers/task_builder
import sb/extra/report
import sb/extra_server/yaml
import sb/forms/error
import sb/forms/options
import sb/forms/value

pub fn duplicate_options_test() {
  let input =
    helpers.multi_line({
      "
      kind: tasks/v1
      category: [category]
      ---
      name: task
      fields:
        - {id: field1, kind: checkbox, source.literal: [ichi, ni, san]}
        - {id: field2, kind: checkbox, source.literal: [ichi, ni, ni, san]}
      "
    })

  let task =
    task_builder.new(input, yaml.decode_string)
    |> task_builder.build
    |> should.be_ok

  helpers.field_errors(task) |> should.equal([])

  helpers.field_options(task, "field1")
  |> should.be_ok
  |> options.unique_keys
  |> should.be_ok

  helpers.field_options(task, "field2")
  |> should.be_ok
  |> options.unique_keys
  |> should.be_error
  |> report.issue
  |> should.equal(error.DuplicateKeys([value.String("ni")]))
}
