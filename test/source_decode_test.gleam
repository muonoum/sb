import gleam/dynamic
import gleam/result
import gleeunit/should
import helpers
import sb/extra/dots
import sb/extra/report.{type Report}
import sb/extra/state
import sb/extra/yaml
import sb/forms/custom
import sb/forms/error.{type Error}
import sb/forms/props
import sb/forms/source.{type Source}

pub const custom_sources = "
recursive-source:
  kind: fetch
  url: http://example.org
  body:
    kind: recursive-source
"

pub const short_recursive_source = "
source.kind: recursive-source
"

pub const long_recursive_source = "
source:
  kind: recursive-source
"

fn decode_source(
  dynamic: dynamic.Dynamic,
  sources: custom.Sources,
) -> Result(Source, Report(Error)) {
  props.decode(dots.split(dynamic), {
    let decoder = props.decode(_, source.decoder(sources))
    use source <- props.get("source", decoder)
    state.succeed(source)
  })
}

pub fn short_recursive_source_test() {
  let assert Ok([dynamic, ..]) =
    helpers.load_documents(short_recursive_source, yaml.decode_string)

  let assert Ok(sources) =
    helpers.load_custom(custom_sources, yaml.decode_string)
    |> result.map(custom.Sources)

  let report =
    decode_source(dynamic, sources)
    |> should.be_error

  report.issue
  |> should.equal(error.BadProperty("source"))

  report.context
  |> should.equal([
    error.BadKind("fetch"),
    error.BadProperty("body"),
    error.Recursive("recursive-source"),
  ])
}

pub fn long_recursive_source_test() {
  let assert Ok([dynamic, ..]) =
    helpers.load_documents(long_recursive_source, yaml.decode_string)

  let assert Ok(sources) =
    helpers.load_custom(custom_sources, yaml.decode_string)
    |> result.map(custom.Sources)

  let report =
    decode_source(dynamic, sources)
    |> should.be_error

  report.issue
  |> should.equal(error.BadProperty("source"))

  report.context
  |> should.equal([
    error.BadKind("fetch"),
    error.BadProperty("body"),
    error.Recursive("recursive-source"),
  ])
}
