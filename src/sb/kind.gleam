import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/set.{type Set}
import sb/choice.{type Choice}
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
  Radio(Option(Choice), options: Options)
  Select(Option(Choice), options: Options)
  Checkbox(List(Choice), options: Options)
  MultiSelect(List(Choice), options: Options)
}

pub fn reset(kind: Kind, refs: Set(String)) -> Kind {
  case kind {
    Text(..) | Textarea(..) -> kind
    Data(source:) -> Data(reset.maybe(source, refs))

    Radio(selected, options:) -> {
      let options = options.reset(options, refs)
      let selected = select_one(selected, options)
      Radio(selected, options:)
    }

    Select(selected, options:) -> {
      let options = options.reset(options, refs)
      let selected = select_one(selected, options)
      Select(selected, options:)
    }

    Checkbox(selected, options:) -> {
      let options = options.reset(options, refs)
      let selected = select_multiple(selected, options)
      Checkbox(selected, options:)
    }

    MultiSelect(selected, options:) -> {
      let options = options.reset(options, refs)
      let selected = select_multiple(selected, options)
      MultiSelect(selected, options:)
    }
  }
}

fn select_one(selected: Option(Choice), options: Options) -> Option(Choice) {
  let selected =
    option.map(selected, choice.key)
    |> option.map(options.select(options, _))

  case selected {
    None | Some(Error(..)) -> None
    Some(Ok(selected)) -> Some(selected)
  }
}

fn select_multiple(selected: List(Choice), options: Options) -> List(Choice) {
  let selected =
    list.map(selected, choice.key)
    |> list.try_map(options.select(options, _))

  case selected {
    Ok([]) | Error(..) -> []
    Ok(selected) -> selected
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

    Radio(Some(selected), ..) | Select(Some(selected), ..) ->
      Some(Ok(choice.value(selected)))

    Checkbox(selected, ..) | MultiSelect(selected, ..) ->
      Some(Ok(value.List(list.map(selected, choice.value))))
  }
}
