import exception.{type Exception}
import gleam/dynamic.{type Dynamic}

@external(erlang, "glue", "yamerl_decode_file")
pub fn yamerl_decode_file(path: String) -> Dynamic

pub fn decode_file(path: String) -> Result(Dynamic, Exception) {
  use <- exception.rescue
  yamerl_decode_file(path)
}

@external(erlang, "glue", "yamerl_decode")
pub fn yamerl_decode(path: String) -> Dynamic

pub fn decode_string(data: String) -> Result(Dynamic, Exception) {
  use <- exception.rescue
  yamerl_decode(data)
}
