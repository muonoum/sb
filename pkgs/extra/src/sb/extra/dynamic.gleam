import gleam/dynamic.{type Dynamic}

@external(erlang, "gleam_stdlib", "identity")
@external(javascript, "../gleam_stdlib.mjs", "identity")
pub fn from(a: anything) -> Dynamic
