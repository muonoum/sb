import exception.{type Exception}
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/result
import sb/extra/dots
import sb/extra/report.{type Report}
import sb/forms/custom
import sb/forms/error.{type Error}
import sb/forms/field.{type Field}
import sb/forms/props
import sb/forms/source.{type Source}

pub fn load_documents(
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

pub fn load_custom(
  data: String,
  loader: fn(String) -> Result(Dynamic, Exception),
) -> Result(Dict(String, dict.Dict(String, Dynamic)), Report(Error)) {
  use docs <- result.try(load_documents(data, loader))
  use dict, dynamic <- list.try_fold(docs, dict.new())
  use custom <- result.try(custom.decode(dots.split(dynamic)))
  Ok(dict.merge(dict, custom))
}

pub fn decode_source_property(
  name: String,
  dynamic: dynamic.Dynamic,
  sources: custom.Sources,
) -> Result(Source, Report(Error)) {
  props.decode(dots.split(dynamic), {
    let decoder = props.decode(_, source.decoder(sources))
    use source <- props.get(name, decoder)
    props.succeed(source)
  })
}

pub fn decode_field(
  dynamic: Dynamic,
  fields: custom.Fields,
  sources: custom.Sources,
  filters: custom.Filters,
) -> Result(#(String, Field), Report(Error)) {
  let decoder = field.decoder(fields, sources, filters)
  props.decode(dots.split(dynamic), decoder)
}
