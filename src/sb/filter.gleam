import sb/error.{type Error}
import sb/report.{type Report}
import sb/value.{type Value}

pub type Filter

pub fn evaluate(value: Value, _filter: Filter) -> Result(Value, Report(Error)) {
  Ok(value)
}
