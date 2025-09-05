import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}

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
