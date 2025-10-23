import gleam/dict.{type Dict}
import gleam/option.{type Option}
import gleam/result
import sb/extra/report.{type Report}
import sb/forms/error.{type Error}
import sb/forms/value.{type Value}

type Entry =
  Result(Value, Report(Error))

type Environment =
  Dict(String, Entry)

pub opaque type Scope {
  Scope(state: Result(Environment, Environment))
}

pub fn ok() -> Scope {
  Scope(state: Ok(dict.new()))
}

pub fn error() -> Scope {
  Scope(state: Error(dict.new()))
}

pub fn unwrap(scope: Scope) -> Environment {
  case scope.state {
    Error(environment) -> environment
    Ok(environment) -> environment
  }
}

pub fn is_ok(scope: Scope) -> Bool {
  result.is_ok(scope.state)
}

pub fn is_error(scope: Scope) -> Bool {
  result.is_error(scope.state)
}

pub fn to_list(scope: Scope) -> List(#(String, Entry)) {
  dict.to_list(unwrap(scope))
}

pub fn get(scope: Scope, id: String) -> Result(Entry, Nil) {
  dict.get(unwrap(scope), id)
}

pub fn put(
  scope: Scope,
  id: String,
  result: Result(Value, Report(Error)),
) -> Scope {
  Scope(case scope.state, result {
    Error(dict), result -> Error(dict.insert(dict, id, result))
    Ok(dict), Error(_) -> Error(dict.insert(dict, id, result))
    Ok(dict), Ok(_) -> Ok(dict.insert(dict, id, result))
  })
}

pub fn value(scope: Scope, key: String) -> Option(Result(Value, Report(Error))) {
  option.from_result(get(scope, key))
}
