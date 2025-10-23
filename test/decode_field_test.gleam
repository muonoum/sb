import gleam/dict
import gleam/result
import gleeunit/should
import helpers
import sb/extra_server/yaml
import sb/forms/custom

pub fn decode_custom_field_test() {
  let custom_fields =
    helpers.multi_line({
      "
      custom-field:
        kind: data
        source.literal: [1, 2, 3]
      "
    })

  let assert Ok(fields) =
    helpers.load_custom(custom_fields, yaml.decode_string)
    |> result.map(custom.Fields)

  let custom_field =
    helpers.multi_line({
      "
      id: a
      kind: custom-field
      "
    })

  let assert Ok([dynamic, ..]) =
    helpers.load_documents(custom_field, yaml.decode_string)

  let sources = custom.Sources(dict.new())
  let filters = custom.Filters(dict.new())

  helpers.decode_field(dynamic, fields:, sources:, filters:)
  |> should.be_ok
}
