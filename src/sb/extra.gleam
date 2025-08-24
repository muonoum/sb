import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}

pub fn return(a: fn(a) -> b, body: fn() -> a) -> b {
  a(body())
}

@external(erlang, "gleam_stdlib", "identity")
@external(javascript, "../gleam_stdlib.mjs", "identity")
pub fn dynamic_from(a: anything) -> Dynamic

@external(erlang, "glue", "merge_maps")
pub fn merge_dicts(
  dict1: Dict(String, Dynamic),
  dict2: Dict(String, Dynamic),
) -> Dict(String, Dynamic)

pub fn collect_errors(
  errors: List(e),
  zero zero: v,
  value value: Result(v, e),
) -> #(v, List(e)) {
  case value {
    Error(error) -> #(zero, [error, ..errors])
    Ok(value) -> #(value, errors)
  }
}
