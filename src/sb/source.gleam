import sb/error.{type Error}
import sb/scope.{type Scope}
import sb/value.{type Value}

pub type Source {
  Loading(fn() -> Result(Source, Error))
  Literal(Value)
  Reference(String)
}

pub fn refs(source: Source) -> List(String) {
  case source {
    Literal(..) | Loading(..) -> []
    Reference(id) -> [id]
  }
}

pub fn evaluate(source: Source, scope: Scope) -> Result(Source, Error) {
  case source {
    Loading(load) -> load()
    Literal(value) -> Ok(Literal(value))

    Reference(id) ->
      case scope.value(scope, id) {
        Ok(value) -> Ok(Literal(value))
        Error(Nil) -> Ok(Reference(id))
      }
  }
}
