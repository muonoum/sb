import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/result
import sb/extra/dots
import sb/extra/report.{type Report}
import sb/forms/custom
import sb/forms/error.{type Error}

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
  loader: fn(String) -> Result(Dynamic, Dynamic),
) -> Result(Dict(String, dict.Dict(String, Dynamic)), Report(Error)) {
  use docs <- result.try(load_documents(data, loader))
  use dict, dynamic <- list.try_fold(docs, dict.new())
  use custom <- result.try(custom.decode(dots.split(dynamic)))
  Ok(dict.merge(dict, custom))
}
