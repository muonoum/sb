import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/result
import pprint
import sb/extra/dots
import sb/extra/report.{type Report}
import sb/extra/state
import sb/extra/yaml
import sb/forms/custom
import sb/forms/error.{type Error}
import sb/forms/props
import sb/forms/source

pub const short_custom_source = "
source.kind: custom-source
"

pub const long_custom_source = "
source:
  kind: custom-source
"

pub const short_fetch_source = "
source.fetch: http://example.org
"

pub const long_fetch_source = "
source:
  kind: fetch
  url: http://example.org
"

pub fn main() {
  let assert Ok([dynamic, ..]) =
    load_documents(long_fetch_source, yaml.decode_string)

  let assert Ok(sources) =
    load_custom("test_data/sources.yaml", yaml.decode_file)
    |> result.map(custom.Sources)

  pprint.debug(
    props.decode(dots.split(dynamic), {
      use source <- props.get("source", props.decode(_, source.decoder(sources)))
      state.succeed(source)
    }),
  )
}

fn load_documents(
  data: String,
  loader: fn(String) -> Result(Dynamic, _),
) -> Result(List(Dynamic), Report(Error)) {
  use dynamic <- result.try(
    loader(data)
    |> report.map_error(error.YamlError),
  )

  use docs <- result.try(
    decode.run(dynamic, decode.list(decode.dynamic))
    |> report.map_error(error.DecodeError),
  )

  Ok(list.map(docs, dots.split))
}

fn load_custom(
  data: String,
  loader: fn(String) -> Result(Dynamic, Dynamic),
) -> Result(Dict(String, Dict(String, Dynamic)), Report(Error)) {
  use docs <- result.try(load_documents(data, loader))
  use dict, dynamic <- list.try_fold(docs, dict.new())
  use custom <- result.try(custom.decode(dots.split(dynamic)))
  Ok(dict.merge(dict, custom))
}
