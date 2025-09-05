import extra/state
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import sb/decoder
import sb/props

pub type Custom =
  Dict(String, Dynamic)

pub type Fields {
  Fields(custom: Dict(String, Custom))
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

pub fn get_filter(
  filters: Filters,
  name: String,
) -> Result(Dict(String, Dynamic), Nil) {
  dict.get(filters.custom, name)
}

pub fn decoder() {
  use id <- props.get("id", decoder.from(decode.string))
  use dict <- props.get_dict()
  state.succeed(#(id, dict.drop(dict, ["id"])))
}
