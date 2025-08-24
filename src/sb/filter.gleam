import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/result
import sb/error.{type Error}
import sb/report.{type Report}
import sb/value.{type Value}

pub fn keys(name: String) -> Result(List(String), Report(Error)) {
  case name {
    "succeed" | "parse-integer" | "parse-float" -> Ok(["kind"])
    "fail" -> Ok(["kind", "error-message"])
    _unknown -> report.error(error.UnknownKind(name))
  }
}

pub type Filter {
  Succeed
}

pub fn evaluate(value: Value, filter: Filter) -> Result(Value, Report(Error)) {
  case filter {
    Succeed -> Ok(value)
  }
}

pub fn decoder(
  dynamic: Dynamic,
  filters: Dict(String, Dict(String, Dynamic)),
) -> Result(Filter, Report(Error)) {
  decode.run(dynamic, decode.dict(decode.string, decode.dynamic))
  |> report.map_error(error.DecodeError)
  |> result.try(dict_decoder(_, filters))
}

fn dict_decoder(
  dict: Dict(String, Dynamic),
  filters: Dict(String, Dict(String, Dynamic)),
) -> Result(Filter, Report(Error)) {
  use kind <- result.try(case dict.get(dict, "kind") {
    Error(Nil) -> error.missing_property("kind")

    Ok(dynamic) ->
      decode.run(dynamic, decode.string)
      |> error.bad_property("category")
  })

  case dict.get(filters, kind) {
    Error(Nil) -> kind_decoder(kind, dict)
    Ok(custom) -> dict_decoder(dict.merge(dict, custom), filters)
  }
}

fn kind_decoder(
  kind: String,
  dict: Dict(String, Dynamic),
) -> Result(Filter, Report(Error)) {
  use keys <- result.try(keys(kind))
  use _dict <- result.try(error.unknown_keys(dict, [keys]))

  case kind {
    "succeed" -> Ok(Succeed)
    unknown -> report.error(error.UnknownKind(unknown))
  }
}
