import gleeunit/should
import helpers
import sb/extra_server/yaml

pub fn builtin_field_test() {
  let input =
    helpers.multi_line({
      "
      kind: fields/v1
      ---
      id: data
      kind: text
      "
    })

  helpers.load_custom_fields(input, yaml.decode_string)
  |> should.be_error
}

pub fn builtin_filter_test() {
  let input =
    helpers.multi_line({
      "
      kind: filters/v1
      ---
      id: succeed
      kind: fail
      error-message: nope
      "
    })

  helpers.load_custom_filters(input, yaml.decode_string)
  |> should.be_error
}

pub fn builtin_source_test() {
  let input =
    helpers.multi_line({
      "
      kind: sources/v1
      ---
      id: literal
      literal: [a, b, c]
      "
    })

  helpers.load_custom_sources(input, yaml.decode_string)
  |> should.be_error
}
