import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/set.{type Set}
import sb/error.{type Error}
import sb/options.{type Options}
import sb/reset.{type Reset}
import sb/scope.{type Scope}
import sb/source.{type Source}
import sb/value.{type Value}

pub type Kind {
  Text(String)
  Textarea(String)
  Data(source: Reset(Result(Source, Error)))
  Radio(Option(Value), options: Options)
  Select(Option(Value), options: Options)
  Checkbox(List(Value), options: Options)
  MultiSelect(List(Value), options: Options)
}

pub fn reset(kind: Kind, refs: Set(String)) -> Kind {
  case kind {
    Text(..) | Textarea(..) -> kind
    Data(source:) -> Data(reset.maybe(source, refs))

    Radio(selected, options:) -> {
      // let options = options.reset(options, refs)

      // case option.map(echo selected, options.select(echo options, _)) |> echo {
      //   None | Some(Error(..)) -> Radio(None, options:)
      //   Some(Ok(selected)) -> Radio(Some(selected), options:)
      // }
      Radio(selected, options.reset(options, refs))
    }

    Select(selected, options:) -> Select(selected, options.reset(options, refs))

    Checkbox(selected, options:) ->
      Checkbox(selected, options.reset(options, refs))

    MultiSelect(selected, options:) ->
      MultiSelect(selected, options.reset(options, refs))
  }
}

pub fn evaluate(kind: Kind, scope: Scope) -> Kind {
  case kind {
    Text(..) | Textarea(..) -> kind

    Data(source:) ->
      Data(source: {
        use source <- reset.map(source)
        use source <- result.try(source)
        source.evaluate(source, scope)
      })

    Radio(selected, options:) ->
      Radio(selected, options: options.evaluate(options, scope))

    Select(selected, options:) ->
      Select(selected, options: options.evaluate(options, scope))

    Checkbox(selected, options:) ->
      Checkbox(selected, options: options.evaluate(options, scope))

    MultiSelect(selected, options:) ->
      MultiSelect(selected, options: options.evaluate(options, scope))
  }
}

pub fn update(kind: Kind, value: Value) -> Result(Kind, Error) {
  case kind, value {
    Data(..), _value -> Error(error.BadKind)

    Text(..), value.String(string) -> Ok(Text(string))
    Textarea(..), value.String(string) -> Ok(Textarea(string))
    Text(..), value | Textarea(..), value -> Error(error.BadValue(value))

    Radio(_selected, options:), key -> {
      use selected <- result.try(options.select(options, key))
      Ok(Radio(Some(selected), options:))
    }

    Select(_selected, options:), key -> {
      use selected <- result.try(options.select(options, key))
      Ok(Select(Some(selected), options:))
    }

    Checkbox(_selected, options:), value.List(keys) -> {
      use selected <- result.try(list.try_map(keys, options.select(options, _)))
      Ok(Checkbox(selected, options:))
    }

    MultiSelect(_selected, options:), value.List(keys) -> {
      use selected <- result.try(list.try_map(keys, options.select(options, _)))
      Ok(MultiSelect(selected, options:))
    }

    Checkbox(..), value | MultiSelect(..), value -> Error(error.BadValue(value))
  }
}

pub fn value(kind: Kind) -> Option(Result(Value, Error)) {
  case kind {
    Text("") | Textarea("") -> None
    Radio(None, ..) | Select(None, ..) -> None
    Checkbox([], ..) | MultiSelect([], ..) -> None

    Text(string) | Textarea(string) -> Some(Ok(value.String(string)))

    Data(source:) ->
      case reset.unwrap(source) {
        Error(error) -> Some(Error(error))
        Ok(source.Literal(value)) -> Some(Ok(value))
        Ok(..) -> None
      }

    Radio(Some(selected), ..) | Select(Some(selected), ..) -> Some(Ok(selected))

    Checkbox(selected, ..) | MultiSelect(selected, ..) ->
      Some(Ok(value.List(selected)))
  }
}
