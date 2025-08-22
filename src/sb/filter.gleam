import sb/error.{type Error}
import sb/value.{type Value}

pub fn evaluate(value: Value, _filter) -> Result(Value, Error) {
  Ok(value)
}
