import gleam/dict.{type Dict}
import gleam/option.{type Option, None, Some}
import gleam/result
import sb/extra/report.{type Report}
import sb/forms/error.{type Error}
import sb/forms/value.{type Value}

type Values =
  Dict(String, Result(Value, Report(Error)))

pub opaque type Scope {
  Scope(state: Result(Values, Values))
}

pub fn ok() -> Scope {
  Scope(state: Ok(dict.new()))
}

pub fn error() -> Scope {
  Scope(state: Error(dict.new()))
}

pub fn unwrap(scope: Scope) -> Values {
  result.unwrap_both(scope.state)
}

pub fn is_ok(scope: Scope) -> Bool {
  result.is_ok(scope.state)
}

pub fn to_list(scope: Scope) -> List(#(String, Result(Value, Report(Error)))) {
  dict.to_list(unwrap(scope))
}

pub fn get(
  scope: Scope,
  id: String,
) -> Result(Result(Value, Report(Error)), Nil) {
  dict.get(unwrap(scope), id)
}

pub fn put(scope: Scope, id, result) -> Scope {
  Scope(case scope.state, result {
    Error(dict), result -> Error(dict.insert(dict, id, result))
    Ok(dict), Error(_) -> Error(dict.insert(dict, id, result))
    Ok(dict), Ok(_) -> Ok(dict.insert(dict, id, result))
  })
}

pub fn value(scope: Scope, key: String) -> Option(Result(Value, Report(Error))) {
  case dict.get(unwrap(scope), key) {
    Error(Nil) -> None
    Ok(Error(report)) -> Some(Error(report))
    Ok(Ok(value)) -> Some(Ok(value))
  }
}
