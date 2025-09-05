import extra
import extra/state
import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/result
import sb/decoder
import sb/error.{type Error}
import sb/props.{type Props}
import sb/report.{type Report}
import sb/scope.{type Scope}
import sb/value.{type Value}
import sb/zero.{type Zero}

pub opaque type Condition {
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
  case decoder.run(dynamic, decode.bool) {
    Ok(bool) -> Ok(Resolved(bool))
    Error(..) -> props.decode(dynamic, kind_decoder())
  }
}

pub fn zero_decoder() -> Zero(Condition) {
  use dynamic <- zero.new(false())
  decoder(dynamic)
}

fn kind_decoder() -> Props(Condition) {
  use dict <- props.get_dict

  case dict.to_list(dict) {
    [#("when", dynamic)] -> {
      use <- extra.return(props.error_context(error.BadCondition("when")))
      condition_decoder(dynamic, Defined, Equal)
    }

    [#("unless", dynamic)] -> {
      use <- extra.return(props.error_context(error.BadCondition("unless")))
      condition_decoder(dynamic, NotDefined, NotEqual)
    }

    [#(_unknown, _)] -> todo as "unknown condition"
    _bad -> todo as "bad condition"
  }
}

fn condition_decoder(
  dynamic: Dynamic,
  defined: fn(String) -> Condition,
  equal: fn(String, Value) -> Condition,
) -> Props(Condition) {
  use <- extra.return(state.from_result)

  use <- result.lazy_or(
    decoder.run(dynamic, decode.string)
    |> result.map(defined),
  )

  use <- extra.return(props.decode(dynamic, _))
  use dict <- props.get_dict

  case dict.to_list(dict) {
    [#(id, dynamic)] ->
      case decoder.run(dynamic, value.decoder()) {
        Error(error) -> state.fail(error)
        Ok(value) -> state.succeed(equal(id, value))
      }

    _bad -> todo as "bad condition"
  }
}
