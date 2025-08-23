import gleam/option.{None, Some}
import sb/error.{type Error}
import sb/report.{type Report}
import sb/scope.{type Scope}
import sb/text.{type Text}
import sb/value.{type Value}

pub type Source {
  Loading(fn() -> Result(Source, Report(Error)))
  Literal(Value)
  Reference(String)
  Template(Text)
}

pub fn refs(source: Source) -> List(String) {
  case source {
    Literal(..) | Loading(..) -> []
    Reference(id) -> [id]
    Template(text) -> text.refs(text)
  }
}

pub fn evaluate(source: Source, scope: Scope) -> Result(Source, Report(Error)) {
  case source {
    Loading(load) -> load()
    Literal(value) -> Ok(Literal(value))

    Reference(id) ->
      case scope.value(scope, id) {
        Ok(value) -> Ok(Literal(value))
        Error(Nil) -> Ok(Reference(id))
      }

    Template(text) ->
      case text.evaluate(text, scope, placeholder: None) {
        Error(report) -> Error(report)
        Ok(None) -> Ok(Template(text))
        Ok(Some(string)) -> Ok(Literal(value.String(string)))
      }
  }
}
