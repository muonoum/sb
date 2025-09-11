import gleam/result
import helpers
import pprint
import sb/extra/dots
import sb/extra/yaml
import sb/forms/custom
import sb/forms/props
import sb/forms/source

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

pub fn main() {
  let assert Ok([dynamic, ..]) =
    helpers.load_documents(short_recursive_source, yaml.decode_string)

  let assert Ok(sources) =
    helpers.load_custom(custom_sources, yaml.decode_string)
    |> result.map(custom.Sources)

  pprint.debug(
    props.decode(dots.split(dynamic), {
      let decoder = props.decode(_, source.decoder(sources))
      use source <- props.get("source", decoder)
      props.succeed(source)
    }),
  )
}
