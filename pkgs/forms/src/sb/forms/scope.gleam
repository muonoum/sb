import gleam/dict.{type Dict}
import sb/extra/report.{type Report}
import sb/forms/error.{type Error}
import sb/forms/value.{type Value}

pub type Scope =
  Dict(String, Result(Value, Report(Error)))

pub fn value(scope: Scope, key: String) -> Result(Value, Nil) {
  case dict.get(scope, key) {
    Ok(Ok(value)) -> Ok(value)
    Ok(Error(_report)) -> Error(Nil)
    Error(Nil) -> Error(Nil)
  }
}
