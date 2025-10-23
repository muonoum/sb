import exception.{type Exception}
import gleam/dynamic.{type Dynamic}

@external(erlang, "glue", "yamerl_decode_file")
pub fn yamerl_decode_file(path: String) -> Dynamic

pub fn decode_file(path: String) -> Result(Dynamic, Exception) {
  use <- exception.rescue
  yamerl_decode_file(path)
}

@external(erlang, "glue", "yamerl_decode_string")
pub fn yamerl_decode_string(string: String) -> Dynamic

pub fn decode_string(string: String) -> Result(Dynamic, Exception) {
  use <- exception.rescue
  yamerl_decode_string(string)
}
