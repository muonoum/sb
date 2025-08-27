import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/set.{type Set}
import sb/choice.{type Choice}
import sb/error.{type Error}
import sb/handlers.{type Handlers}
import sb/options.{type Options}
import sb/report.{type Report}
import sb/reset.{type Reset}
import sb/scope.{type Scope}
import sb/source.{type Source}
import sb/value.{type Value}

pub fn keys(name: String) -> Result(List(String), Report(Error)) {
  case name {
    "data" -> Ok(["source"])
    "markdown" -> Ok(["source"])
    "text" -> Ok(["default", "placeholder"])
    "textarea" -> Ok(["default", "placeholder"])
    "radio" -> Ok(["default", "layout", "source"])
    "checkbox" -> Ok(["default", "layout", "source"])
    "select" -> Ok(["default", "multiple", "placeholder", "source"])
    _unknown -> report.error(error.UnknownKind(name))
  }
}

pub type Kind {
  Text(String)
  Textarea(String)
  Data(source: Reset(Result(Source, Report(Error))))
  Select(Option(Choice), options: Options)
  MultiSelect(List(Choice), options: Options)
}

pub fn data(source: Source) -> Kind {
  Data(source: reset.try_new(Ok(source), source.refs))
}

pub fn select(options: Options) -> Kind {
  Select(None, options:)
}

pub fn multi_select(options: Options) -> Kind {
  MultiSelect([], options:)
}

pub fn reset(kind: Kind, refs: Set(String)) -> Kind {
  case kind {
    Text(..) | Textarea(..) -> kind
    Data(source:) -> Data(reset.maybe(source, refs))

    Select(selected, options:) -> {
      let options = options.reset(options, refs)
      let selected = select_one(selected, options)
      Select(selected, options:)
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

pub fn evaluate(
  kind: Kind,
  scope: Scope,
  search: Option(String),
  handlers: Handlers,
) -> Kind {
  case kind {
    Text(..) | Textarea(..) -> kind

    Data(source:) ->
      Data(source: {
        use source <- reset.map(source)
        use source <- result.try(source)
        source.evaluate(source, scope, search:, handlers:)
      })

    Select(selected, options:) ->
      Select(selected, options: options.evaluate(options, scope))

    MultiSelect(selected, options:) ->
      MultiSelect(selected, options: options.evaluate(options, scope))
  }
}

pub fn update(kind: Kind, value: Value) -> Result(Kind, Report(Error)) {
  case kind, value {
    Data(..), _value -> report.error(error.BadKind("data"))

    Text(..), value.String(string) -> Ok(Text(string))
    Textarea(..), value.String(string) -> Ok(Textarea(string))
    Text(..), value | Textarea(..), value -> report.error(error.BadValue(value))

    Select(_selected, options:), key -> {
      use selected <- result.try(options.select(options, key))
      Ok(Select(Some(selected), options:))
    }

    MultiSelect(_selected, options:), value.List(keys) -> {
      use selected <- result.try(list.try_map(keys, options.select(options, _)))
      Ok(MultiSelect(selected, options:))
    }

    MultiSelect(..), value -> report.error(error.BadValue(value))
  }
}

pub fn value(kind: Kind) -> Option(Result(Value, Report(Error))) {
  case kind {
    Text("") | Textarea("") -> None
    Select(None, ..) | MultiSelect([], ..) -> None

    Text(string) | Textarea(string) -> Some(Ok(value.String(string)))

    Data(source:) ->
      case reset.unwrap(source) {
        Error(report) -> Some(Error(report))
        Ok(source.Literal(value)) -> Some(Ok(value))
        Ok(..) -> None
      }

    Select(Some(selected), ..) -> Some(Ok(choice.value(selected)))

    MultiSelect(selected, ..) ->
      Some(Ok(value.List(list.map(selected, choice.value))))
  }
}

pub fn decoder(
  kind: String,
  dict: Dict(String, Dynamic),
) -> Result(Kind, Report(Error)) {
  case kind {
    "data" -> data_decoder(dict)
    "text" -> text_decoder(dict)
    "textarea" -> textarea_decoder(dict)
    "radio" -> radio_decoder(dict)
    "checkbox" -> checkbox_decoder(dict)
    "select" -> select_decoder(dict)
    unknown -> report.error(error.UnknownKind(unknown))
  }
}

fn data_decoder(dict: Dict(String, Dynamic)) -> Result(Kind, Report(Error)) {
  use source <- result.try({
    case dict.get(dict, "source") {
      Error(Nil) -> report.error(error.MissingProperty("source"))
      Ok(dynamic) -> Ok(source.decoder(dynamic))
    }
  })

  Ok(Data(source: reset.try_new(source, source.refs)))
}

fn text_decoder(_dict: Dict(String, Dynamic)) -> Result(Kind, Report(Error)) {
  todo
}

fn textarea_decoder(_dict: Dict(String, Dynamic)) -> Result(Kind, Report(Error)) {
  todo
}

fn radio_decoder(_dict: Dict(String, Dynamic)) -> Result(Kind, Report(Error)) {
  todo
}

fn checkbox_decoder(_dict: Dict(String, Dynamic)) -> Result(Kind, Report(Error)) {
  todo
}

fn select_decoder(dict: Dict(String, Dynamic)) -> Result(Kind, Report(Error)) {
  use multiple <- result.try({
    case dict.get(dict, "multiple") {
      Error(Nil) -> Ok(False)

      Ok(dynamic) ->
        decode.run(dynamic, decode.bool)
        |> report.map_error(error.DecodeError)
        |> report.error_context(error.BadProperty("multiple"))
    }
  })

  use options <- result.try({
    case dict.get(dict, "source") {
      Error(Nil) -> report.error(error.MissingProperty("source"))

      Ok(dynamic) ->
        options.decoder(dynamic)
        |> report.error_context(error.BadProperty("source"))
    }
  })

  Ok(case multiple {
    False -> Select(None, options:)
    True -> MultiSelect([], options:)
  })
}
