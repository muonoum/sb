import gleam/bool
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/set.{type Set}
import sb/extra/report.{type Report}
import sb/extra/reset.{type Reset}
import sb/extra/state
import sb/forms/choice.{type Choice}
import sb/forms/custom
import sb/forms/decoder
import sb/forms/error.{type Error}
import sb/forms/handlers.{type Handlers}
import sb/forms/options.{type Options}
import sb/forms/props.{type Props}
import sb/forms/scope.{type Scope}
import sb/forms/source.{type Source}
import sb/forms/value.{type Value}
import sb/forms/zero

pub const builtin = [
  "data", "markdown", "text", "textarea", "radio", "checkbox", "select",
]

pub const data_keys = ["source"]

pub const text_keys = ["default", "placeholder"]

pub const textarea_keys = ["default", "placeholder"]

pub const radio_keys = ["default", "layout", "source"]

pub const checkbox_keys = ["default", "layout", "source"]

pub const select_keys = ["default", "multiple", "placeholder", "source"]

pub type Kind {
  Text(string: String, placeholder: Option(String))
  Textarea(string: String, placeholder: Option(String))
  Data(source: Reset(Result(Source, Report(Error))))
  Select(choice: Option(Choice), placeholder: Option(String), options: Options)
  MultiSelect(choice: List(Choice), options: Options)
}

pub fn reset(kind: Kind, refs: Set(String)) -> Kind {
  case kind {
    Text(..) | Textarea(..) -> kind
    Data(source:) -> Data(reset.maybe(source, refs))

    Select(choice:, options:, ..) -> {
      let options = options.reset(options, refs)
      let choice = select_one(choice, options)
      Select(..kind, choice:, options:)
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

    Select(choice:, options:, placeholder:) ->
      options.evaluate(options, scope, search:, handlers:)
      |> Select(choice:, options: _, placeholder:)

    MultiSelect(selected, options:) ->
      options.evaluate(options, scope, search:, handlers:)
      |> MultiSelect(selected, options: _)
  }
}

pub fn update(kind: Kind, value: Value) -> Result(Kind, Report(Error)) {
  case kind, value {
    Data(..), _value -> report.error(error.BadKind("data"))

    Text(..), value.String(string) -> Ok(Text(..kind, string:))
    Textarea(..), value.String(string) -> Ok(Textarea(..kind, string:))
    Text(..), value | Textarea(..), value -> report.error(error.BadValue(value))

    Select(options:, ..), key -> {
      use selected <- result.try(options.select(options, key))
      Ok(Select(..kind, choice: Some(selected), options:))
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
    Text("", ..) | Textarea("", ..) -> None
    Select(None, ..) | MultiSelect([], ..) -> None

    Text(string:, ..) | Textarea(string:, ..) -> Some(Ok(value.String(string)))

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
  name: String,
  sources: custom.Sources,
  check_keys: fn(List(String)) -> Props(Nil),
) -> Props(Kind) {
  case name {
    "data" -> {
      use <- state.do(check_keys(data_keys))
      data_decoder(sources)
      |> props.error_context(error.BadKind(name))
    }

    "text" ->
      state.do(check_keys(text_keys), text_decoder)
      |> props.error_context(error.BadKind(name))

    "textarea" ->
      state.do(check_keys(textarea_keys), textarea_decoder)
      |> props.error_context(error.BadKind(name))

    "radio" -> {
      use <- state.do(check_keys(radio_keys))
      radio_decoder(sources)
      |> props.error_context(error.BadKind(name))
    }

    "checkbox" -> {
      use <- state.do(check_keys(checkbox_keys))
      checkbox_decoder(sources)
      |> props.error_context(error.BadKind(name))
    }

    "select" -> {
      use <- state.do(check_keys(select_keys))
      select_decoder(sources)
      |> props.error_context(error.BadKind(name))
    }

    unknown -> props.fail(report.new(error.UnknownKind(unknown)))
  }
}

fn data_decoder(sources: custom.Sources) -> Props(Kind) {
  use source <- props.get("source", {
    props.decode(_, {
      state.map(source.decoder(sources), Ok)
      |> state.attempt(state.catch_error)
      |> state.map(reset.try_new(_, source.refs))
    })
  })

  props.succeed(Data(source:))
}

fn text_decoder() -> Props(Kind) {
  use placeholder <- props.try("placeholder", {
    zero.option(decoder.from(decode.string))
  })

  use string <- props.try("default", zero.string(decoder.from(decode.string)))
  props.succeed(Text(string:, placeholder:))
}

fn textarea_decoder() -> Props(Kind) {
  use placeholder <- props.try("placeholder", {
    zero.option(decoder.from(decode.string))
  })

  use string <- props.try("default", zero.string(decoder.from(decode.string)))
  props.succeed(Textarea(string:, placeholder:))
}

fn radio_decoder(sources: custom.Sources) -> Props(Kind) {
  use placeholder <- props.try("placeholder", {
    zero.option(decoder.from(decode.string))
  })

  // TODO: radio
  use options <- props.get("source", props.decode(_, options.decoder(sources)))
  props.succeed(Select(choice: None, placeholder:, options:))
}

fn checkbox_decoder(sources: custom.Sources) -> Props(Kind) {
  use options <- props.get("source", props.decode(_, options.decoder(sources)))

  // TODO: checkbox
  props.succeed(MultiSelect([], options:))
}

fn select_decoder(sources: custom.Sources) -> Props(Kind) {
  use placeholder <- props.try("placeholder", {
    zero.option(decoder.from(decode.string))
  })

  use multiple <- props.try("multiple", zero.bool(decoder.from(decode.bool)))
  use options <- props.get("source", props.decode(_, options.decoder(sources)))
  use <- bool.guard(multiple, props.succeed(MultiSelect([], options:)))
  props.succeed(Select(choice: None, placeholder:, options:))
}
