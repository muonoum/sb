import exception
import gleam/dynamic.{type Dynamic}
import gleam/result
import sb/extra

@external(erlang, "glue", "yamerl_decode_file")
pub fn yamerl_decode_file(path: String) -> Dynamic

pub fn decode_file(path: String) -> Result(Dynamic, Dynamic) {
  exception.rescue(fn() { yamerl_decode_file(path) })
  |> result.map_error(extra.dynamic_from)
}

@external(erlang, "glue", "yamerl_decode")
pub fn yamerl_decode(path: String) -> Dynamic

pub fn decode_string(data: String) -> Result(Dynamic, Dynamic) {
  exception.rescue(fn() { yamerl_decode(data) })
  |> result.map_error(extra.dynamic_from)
}
