import gleam/dict
import gleeunit/should
import helpers
import sb/extra_server/yaml
import sb/forms/custom

pub fn short_fetch_test() {
  let input = "source.fetch: http://example.org"

  let assert Ok([dynamic, ..]) =
    helpers.load_documents(input, yaml.decode_string)

  let sources = custom.Sources(dict.new())
  helpers.decode_source_property(dynamic, "source", sources:)
  |> should.be_ok
}

pub fn long_fetch_test() {
  let input =
    helpers.multi_line({
      "
      source.fetch:
        url: http://example.org
      "
    })

  let assert Ok([dynamic, ..]) =
    helpers.load_documents(input, yaml.decode_string)

  let sources = custom.Sources(dict.new())
  helpers.decode_source_property(dynamic, "source", sources:)
  |> should.be_ok
}

pub fn double_fetch_test() {
  let input =
    helpers.multi_line({
      "
      source.fetch:
        url: http://example.org
        body.fetch: http://example.com
      "
    })

  let assert Ok([dynamic, ..]) =
    helpers.load_documents(input, yaml.decode_string)

  let sources = custom.Sources(dict.new())
  helpers.decode_source_property(dynamic, "source", sources:)
  |> should.be_ok
}
