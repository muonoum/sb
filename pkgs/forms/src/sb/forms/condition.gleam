import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/result
import sb/extra/function.{return}
import sb/extra/report
import sb/extra/state_eval as state
import sb/forms/decoder
import sb/forms/error
import sb/forms/props.{type Props}
import sb/forms/scope.{type Scope}
import sb/forms/value.{type Value}
import sb/forms/zero.{type Zero}

pub type Condition {
  Resolved(Bool)
  Defined(String)
  Equal(String, Value)
  NotDefined(String)
  NotEqual(String, Value)
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

pub fn decoder() -> Zero(Condition) {
  use dynamic <- zero.new(Resolved(False))

  case decoder.run(dynamic, decode.bool) {
    Ok(bool) -> Ok(Resolved(bool))
    Error(..) -> props.decode(dynamic, kind_decoder())
  }
}

fn kind_decoder() -> Props(Condition) {
  use dict <- props.get_dict

  case dict.to_list(dict) {
    [#("when", dynamic)] -> {
      use <- return(props.error_context(error.BadCondition("when")))
      condition_decoder(dynamic, Defined, Equal)
    }

    [#("unless", dynamic)] -> {
      use <- return(props.error_context(error.BadCondition("unless")))
      condition_decoder(dynamic, NotDefined, NotEqual)
    }

    // TODO
    [#(unknown, _)] -> props.fail(report.new(error.Message(unknown)))
    _bad -> props.fail(report.new(error.Message("bad condition")))
  }
}

fn condition_decoder(
  dynamic: Dynamic,
  defined: fn(String) -> Condition,
  equal: fn(String, Value) -> Condition,
) -> Props(Condition) {
  use <- return(state.from_result)

  use <- result.lazy_or(
    decoder.run(dynamic, decode.string)
    |> result.map(defined),
  )

  use <- return(props.decode(dynamic, _))
  use dict <- props.get_dict

  case dict.to_list(dict) {
    [#(id, dynamic)] ->
      case decoder.run(dynamic, value.decoder()) {
        Error(error) -> props.fail(error)
        Ok(value) -> props.succeed(equal(id, value))
      }

    // TODO
    _bad -> props.fail(report.new(error.Message("bad condition")))
  }
}
