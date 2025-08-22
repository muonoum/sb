import gleam/dict
import sb/scope.{type Scope}
import sb/value.{type Value}

pub type Condition {
  Resolved(Bool)
  Defined(String)
  Equal(String, Value)
  NotDefined(String)
  NotEqual(String, Value)
}

pub fn true() -> Condition {
  Resolved(True)
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
