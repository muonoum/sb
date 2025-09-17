import gleam/dict
import gleeunit/should
import helpers
import sb/extra_server/yaml
import sb/forms/custom

pub const short_fetch = "
source.fetch: http://example.org
"

pub const long_fetch = "
source.fetch:
  url: http://example.org
"

pub const longest_fetch = "
source:
  kind: fetch
  url: http://example.org
"

pub const double_fetch = "
source.fetch:
  url: http://example.org
  body.fetch: http://example.com
"

pub fn short_fetch_test() {
  let assert Ok([dynamic, ..]) =
    helpers.load_documents(short_fetch, yaml.decode_string)

  helpers.decode_source_property(
    "source",
    dynamic,
    sources: custom.Sources(dict.new()),
  )
  |> should.be_ok
}

pub fn long_fetch_test() {
  let assert Ok([dynamic, ..]) =
    helpers.load_documents(long_fetch, yaml.decode_string)

  helpers.decode_source_property(
    "source",
    dynamic,
    sources: custom.Sources(dict.new()),
  )
  |> should.be_ok
}

pub fn longest_fetch_test() {
  let assert Ok([dynamic, ..]) =
    helpers.load_documents(longest_fetch, yaml.decode_string)

  helpers.decode_source_property(
    "source",
    dynamic,
    sources: custom.Sources(dict.new()),
  )
  |> should.be_ok
}

pub fn double_fetch_test() {
  let assert Ok([dynamic, ..]) =
    helpers.load_documents(double_fetch, yaml.decode_string)

  helpers.decode_source_property(
    "source",
    dynamic,
    sources: custom.Sources(dict.new()),
  )
  |> should.be_ok
}
