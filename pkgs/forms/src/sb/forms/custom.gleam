import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode.{type Decoder}
import gleam/result
import gleam/set.{type Set}
import sb/extra/report.{type Report}
import sb/extra/state_try as state
import sb/forms/decoder
import sb/forms/error.{type Error}
import sb/forms/props.{type Props}

pub type Custom =
  Dict(String, Dynamic)

pub type Commands {
  Commands(custom: Dict(String, Custom))
}

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

pub fn decode(dynamic: Dynamic) -> Result(Dict(String, Custom), Report(Error)) {
  decoder.run(dynamic, decode.dict(decode.string, custom_decoder()))
}

fn custom_decoder() -> Decoder(Dict(String, Dynamic)) {
  decode.dict(decode.string, decode.dynamic)
}

pub fn decoder() {
  use id <- props.get("id", decoder.from(decode.string))
  use dict <- props.get_dict()
  props.succeed(#(id, dict.drop(dict, ["id"])))
}

pub fn kind_decoder(
  seen: Set(String),
  custom: custom,
  get_custom: fn(custom, String) -> Result(Dict(String, Dynamic), _),
  then: fn(Set(String), String) -> Props(v),
) -> Props(v) {
  use name <- props.get("kind", decoder.from(decode.string))

  use <- bool.guard(
    set.contains(seen, name),
    props.fail(report.new(error.Recursive(name))),
  )

  use <- result.lazy_unwrap({
    use dict <- result.map(get_custom(custom, name))
    use <- state.do(props.merge(dict))
    set.insert(seen, name)
    |> kind_decoder(custom, get_custom, then)
  })

  then(seen, name)
}
