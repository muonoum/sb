import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/result
import sb/error.{type Error}
import sb/report.{type Report}
import sb/scope.{type Scope}
import sb/value.{type Value}

// pub opaque type Condition {
pub type Condition {
  Resolved(Bool)
  Defined(String)
  Equal(String, Value)
  NotDefined(String)
  NotEqual(String, Value)
}

pub fn defined(id: String) -> Condition {
  Defined(id)
}

pub fn not_defined(id: String) -> Condition {
  NotDefined(id)
}

pub fn equal(id: String, value: Value) -> Condition {
  Equal(id, value)
}

pub fn not_equal(id: String, value: Value) -> Condition {
  NotEqual(id, value)
}

pub fn resolved(state: Bool) -> Condition {
  Resolved(state)
}

pub fn true() -> Condition {
  Resolved(True)
}

pub fn false() -> Condition {
  Resolved(False)
}

pub fn refs(condition: Condition) -> List(String) {
  case condition {
    Resolved(_) -> []
    Defined(id) -> [id]
    Equal(id, _) -> [id]
    NotDefined(id) -> [id]
    NotEqual(id, _) -> [id]
  }
}

pub fn is_true(cond: Condition) -> Bool {
  case cond {
    Resolved(True) -> True
    _else -> False
  }
}

pub fn evaluate(condition: Condition, scope: Scope) -> Condition {
  case condition {
    Resolved(bool) -> Resolved(bool)

    Defined(id) ->
      case scope.value(scope, id) {
        Ok(_) -> Resolved(True)
        Error(_) -> condition
      }

    NotDefined(id) ->
      case dict.has_key(scope, id) {
        True -> condition
        False -> Resolved(True)
      }

    Equal(id, value) ->
      case scope.value(scope, id) {
        Ok(found) if found == value -> Resolved(True)
        Ok(_) -> condition
        Error(Nil) -> condition
      }

    NotEqual(id, value) ->
      case scope.value(scope, id) {
        Ok(found) if found == value -> condition
        Ok(_) -> Resolved(True)
        Error(Nil) -> Resolved(True)
      }
  }
}

pub fn decoder(dynamic: Dynamic) -> Result(Condition, Report(Error)) {
  case decode.run(dynamic, decode.bool) {
    Ok(bool) -> Ok(Resolved(bool))

    Error(..) ->
      decode.run(dynamic, decode.dict(decode.string, decode.dynamic))
      |> result.try(kind_decoder)
      |> report.map_error(error.DecodeError)
  }
}

fn kind_decoder(
  dict: Dict(String, Dynamic),
) -> Result(Condition, List(decode.DecodeError)) {
  case dict.to_list(dict) {
    [#("when", dynamic)] -> condition_decoder(dynamic, Defined, Equal)
    [#("unless", dynamic)] -> condition_decoder(dynamic, NotDefined, NotEqual)
    [#(_unknown, _)] -> todo
    _bad -> todo
  }
}

fn condition_decoder(
  dynamic: Dynamic,
  defined: fn(String) -> Condition,
  equal: fn(String, Value) -> Condition,
) -> Result(Condition, List(decode.DecodeError)) {
  case decode.run(dynamic, decode.string) {
    Ok(id) -> Ok(defined(id))

    Error(..) -> {
      use dict <- result.try(decode.run(
        dynamic,
        decode.dict(decode.string, decode.dynamic),
      ))

      case dict.to_list(dict) {
        [#(id, dynamic)] ->
          case decode.run(dynamic, value.decoder()) {
            Error(error) -> Error(error)
            Ok(value) -> Ok(equal(id, value))
          }

        _bad -> todo
      }
    }
  }
}
