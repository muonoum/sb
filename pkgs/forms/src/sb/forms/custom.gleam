import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode.{type Decoder}
import sb/extra/report.{type Report}
import sb/forms/decoder
import sb/forms/error.{type Error}

pub type Custom =
  Dict(String, Dynamic)

pub type Fields {
  Fields(custom: Dict(String, Custom))
}

pub type Sources {
  Sources(custom: Dict(String, Custom))
}

pub type Filters {
  Filters(custom: Dict(String, Custom))
}

pub fn get_field(
  fields: Fields,
  name: String,
) -> Result(Dict(String, Dynamic), Nil) {
  dict.get(fields.custom, name)
}

pub fn get_source(
  sources: Sources,
  name: String,
) -> Result(Dict(String, Dynamic), Nil) {
  dict.get(sources.custom, name)
}

pub fn get_filter(
  filters: Filters,
  name: String,
) -> Result(Dict(String, Dynamic), Nil) {
  dict.get(filters.custom, name)
}

// TODO: Duplicate ids

pub fn decode(dynamic: Dynamic) -> Result(Dict(String, Custom), Report(Error)) {
  decoder.run(dynamic, decode.dict(decode.string, custom_decoder()))
}

fn custom_decoder() -> Decoder(Dict(String, Dynamic)) {
  decode.dict(decode.string, decode.dynamic)
}
