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
