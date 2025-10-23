import gleeunit/should
import helpers

pub fn multi_line_test() {
  let input1 =
    helpers.multi_line({
      "
      kind: tasks/v1
      category: [category]
      ---
      name: task-name
      fields:
        - id: field
          kind: text
      "
    })

  let input2 =
    helpers.lines([
      "kind: tasks/v1",
      "category: [category]",
      "---",
      "name: task-name",
      "fields:",
      "  - id: field",
      "    kind: text",
    ])

  input1 |> should.equal(input2)
}
