import gleam/dict
import gleam/result
import gleeunit/should
import helpers
import sb/extra/yaml
import sb/forms/custom

const custom_fields = "
custom-field:
  kind: data
  source.literal: [1, 2, 3]
"

const custom_field = "
id: a
kind: custom-field
"

pub fn decode_custom_field_test() {
  let assert Ok(fields) =
    helpers.load_custom(custom_fields, yaml.decode_string)
    |> result.map(custom.Fields)

  let assert Ok([dynamic, ..]) =
    helpers.load_documents(custom_field, yaml.decode_string)

  let #(_id, _field) =
    helpers.decode_field(
      dynamic,
      fields:,
      sources: custom.Sources(dict.new()),
      filters: custom.Filters(dict.new()),
    )
    |> should.be_ok
}
