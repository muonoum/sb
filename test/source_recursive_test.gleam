import gleam/result
import gleeunit/should
import helpers
import sb/extra/report
import sb/extra_server/yaml
import sb/forms/custom
import sb/forms/error

pub const custom_sources = "
recursive-source1:
  kind: fetch
  url: http://example.org
  body:
    kind: recursive-source1

recursive-source2:
  kind: recursive-source2
"

pub const short_recursive_source1 = "
source.kind: recursive-source1
"

pub const short_recursive_source2 = "
source.kind: recursive-source2
"

pub const long_recursive_source1 = "
source:
  kind: recursive-source1
"

pub const long_recursive_source2 = "
source:
  kind: recursive-source2
"

pub fn short_recursive_source_test() {
  let assert Ok(sources) =
    helpers.load_custom(custom_sources, yaml.decode_string)
    |> result.map(custom.Sources)

  let assert Ok([dynamic, ..]) =
    helpers.load_documents(short_recursive_source1, yaml.decode_string)

  let report =
    helpers.decode_source_property("source", dynamic, sources:)
    |> should.be_error

  report.issue(report)
  |> should.equal(error.BadProperty("source"))

  report.get_context(report)
  |> should.equal([
    error.BadKind("fetch"),
    error.BadProperty("body"),
    error.Recursive("recursive-source1"),
  ])

  let assert Ok([dynamic, ..]) =
    helpers.load_documents(short_recursive_source2, yaml.decode_string)

  let report =
    helpers.decode_source_property("source", dynamic, sources:)
    |> should.be_error

  report.issue(report)
  |> should.equal(error.BadProperty("source"))

  report.get_context(report)
  |> should.equal([
    error.Recursive("recursive-source2"),
  ])
}

pub fn long_recursive_source_test() {
  let assert Ok(sources) =
    helpers.load_custom(custom_sources, yaml.decode_string)
    |> result.map(custom.Sources)

  let assert Ok([dynamic, ..]) =
    helpers.load_documents(long_recursive_source1, yaml.decode_string)

  let report =
    helpers.decode_source_property("source", dynamic, sources:)
    |> should.be_error

  report.issue(report)
  |> should.equal(error.BadProperty("source"))

  report.get_context(report)
  |> should.equal([
    error.BadKind("fetch"),
    error.BadProperty("body"),
    error.Recursive("recursive-source1"),
  ])

  let assert Ok([dynamic, ..]) =
    helpers.load_documents(long_recursive_source2, yaml.decode_string)

  let report =
    helpers.decode_source_property("source", dynamic, sources:)
    |> should.be_error

  report.issue(report)
  |> should.equal(error.BadProperty("source"))

  report.get_context(report)
  |> should.equal([
    error.Recursive("recursive-source2"),
  ])
}
