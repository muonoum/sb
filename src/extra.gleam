import gleam/dynamic.{type Dynamic}

pub fn return(a: fn(a) -> b, body: fn() -> a) -> b {
  a(body())
}

@external(erlang, "gleam_stdlib", "identity")
@external(javascript, "../gleam_stdlib.mjs", "identity")
pub fn dynamic_from(a: anything) -> Dynamic
