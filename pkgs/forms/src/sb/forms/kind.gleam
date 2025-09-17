import gleam/bool
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/set.{type Set}
import sb/extra/function.{return}
import sb/extra/report.{type Report}
import sb/extra/reset.{type Reset}
import sb/extra/state_eval as state
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
  Radio(choice: Option(Choice), options: Options, layout: Layout)
  Select(choice: Option(Choice), options: Options, placeholder: Option(String))
  Checkbox(choices: List(Choice), options: Options, layout: Layout)

  MultiSelect(
    choices: List(Choice),
    placeholder: Option(String),
    options: Options,
  )
}

pub type Layout {
  Column
  Row
}

pub fn sources(kind: Kind) -> List(Reset(Result(Source, Report(Error)))) {
  case kind {
    Text(..) | Textarea(..) -> []
    Data(source) -> [source]

    Radio(options:, ..)
    | Select(options:, ..)
    | Checkbox(options:, ..)
    | MultiSelect(options:, ..) -> options.sources(options)
  }
}

pub fn is_loading(kind: Kind, is_loading: fn(Source) -> Bool) -> Bool {
  case kind {
    Text(..) | Textarea(..) -> False

    Data(source) ->
      reset.unwrap(source)
      |> result.map(is_loading)
      |> result.unwrap(False)

    Radio(options:, ..)
    | Select(options:, ..)
    | Checkbox(options:, ..)
    | MultiSelect(options:, ..) -> options.is_loading(options, is_loading)
  }
}

pub fn reset(kind: Kind, refs: Set(String)) -> Kind {
  case kind {
    Text(..) | Textarea(..) -> kind
    Data(source:) -> Data(reset.maybe(source, refs))

    Radio(choice:, options:, ..) -> {
      let options = options.reset(options, refs)
      let choice = select_one(choice, options)
      Radio(..kind, choice:, options:)
    }

    Select(choice:, options:, ..) -> {
      let options = options.reset(options, refs)
      let choice = select_one(choice, options)
      Select(..kind, choice:, options:)
    }

    Checkbox(choices:, options:, ..) -> {
      let options = options.reset(options, refs)
      let choices = select_multiple(choices, options)
      Checkbox(..kind, choices:, options:)
    }

    MultiSelect(choices:, options:, ..) -> {
      let options = options.reset(options, refs)
      let choices = select_multiple(choices, options)
      MultiSelect(..kind, choices:, options:)
    }
  }
}

// TODO
fn select_one(selected: Option(Choice), options: Options) -> Option(Choice) {
  let selected = {
    use choice <- option.map(selected)
    options.select(options, choice.key(choice))
  }

  case selected {
    None | Some(Error(..)) -> None
    Some(Ok(selected)) -> Some(selected)
  }
}

// TODO
fn select_multiple(selected: List(Choice), options: Options) -> List(Choice) {
  let selected = {
    use choice <- list.try_map(selected)
    options.select(options, choice.key(choice))
  }

  case selected {
    Ok([]) | Error(..) -> []
    Ok(selected) -> selected
  }
}

pub fn evaluate(
  kind: Kind,
  scope: Scope,
  search search: Option(String),
  handlers handlers: Handlers,
) -> Kind {
  case kind {
    Text(..) | Textarea(..) -> kind

    Data(source:) ->
      Data(source: {
        use source <- reset.map(source)
        use source <- result.try(source)
        source.evaluate(source, scope, search:, handlers:)
      })

    Radio(choice:, options:, layout:) ->
      options.evaluate(options, scope, search:, handlers:)
      |> Radio(choice:, options: _, layout:)

    Select(choice:, options:, placeholder:) ->
      options.evaluate(options, scope, search:, handlers:)
      |> Select(choice:, options: _, placeholder:)

    Checkbox(choices:, layout:, options:) ->
      options.evaluate(options, scope, search:, handlers:)
      |> Checkbox(choices:, options: _, layout:)

    MultiSelect(choices:, placeholder:, options:) ->
      options.evaluate(options, scope, search:, handlers:)
      |> MultiSelect(choices:, options: _, placeholder:)
  }
}

pub fn update(kind: Kind, value: Option(Value)) -> Result(Kind, Report(Error)) {
  case kind, value {
    Data(..), _value -> report.error(error.BadKind("data"))

    Text(..), None -> Ok(Text(..kind, string: ""))
    Textarea(..), None -> Ok(Textarea(..kind, string: ""))

    Text(..), Some(value.String(string)) -> Ok(Text(..kind, string:))
    Textarea(..), Some(value.String(string)) -> Ok(Textarea(..kind, string:))

    Radio(..), None -> Ok(Radio(..kind, choice: None))
    Select(..), None -> Ok(Select(..kind, choice: None))
    Checkbox(..), None -> Ok(Checkbox(..kind, choices: []))
    MultiSelect(..), None -> Ok(MultiSelect(..kind, choices: []))

    Radio(options:, ..), Some(key) -> {
      use choice <- result.try(options.select(options, key))
      Ok(Radio(..kind, choice: Some(choice), options:))
    }

    Select(options:, ..), Some(key) -> {
      use choice <- result.try(options.select(options, key))
      Ok(Select(..kind, choice: Some(choice), options:))
    }

    Checkbox(options:, ..), Some(value.List(keys)) -> {
      use choices <- result.try(list.try_map(keys, options.select(options, _)))
      Ok(Checkbox(..kind, choices:, options:))
    }

    MultiSelect(options:, ..), Some(value.List(keys)) -> {
      use choices <- result.try(list.try_map(keys, options.select(options, _)))
      Ok(MultiSelect(..kind, choices:, options:))
    }

    Text(..), Some(value)
    | Textarea(..), Some(value)
    | Checkbox(..), Some(value)
    | MultiSelect(..), Some(value)
    -> report.error(error.BadValue(value))
  }
}

pub fn value(kind: Kind) -> Option(Result(Value, Report(Error))) {
  case kind {
    Text("", ..)
    | Textarea("", ..)
    | Radio(None, ..)
    | Select(None, ..)
    | Checkbox([], ..)
    | MultiSelect([], ..) -> None

    Text(string:, ..) | Textarea(string:, ..) -> Some(Ok(value.String(string)))

    Data(source:) ->
      case reset.unwrap(source) {
        Error(report) -> Some(Error(report))
        Ok(source.Literal(value)) -> Some(Ok(value))
        Ok(..) -> None
      }

    Radio(Some(selected), ..) | Select(Some(selected), ..) ->
      Some(Ok(choice.value(selected)))

    Checkbox(choices:, ..) | MultiSelect(choices:, ..) ->
      Some(Ok(value.List(list.map(choices, choice.value))))
  }
}

pub fn decoder(
  name: String,
  sources sources: custom.Sources,
  then check_keys: fn(List(String)) -> Props(Nil),
) -> Props(Kind) {
  use <- return(props.error_context(error.BadKind(name)))

  case name {
    "data" -> {
      use <- state.do(check_keys(data_keys))
      data_decoder(sources:)
    }

    "text" -> state.do(check_keys(text_keys), text_decoder)
    "textarea" -> state.do(check_keys(textarea_keys), textarea_decoder)

    "radio" -> {
      use <- state.do(check_keys(radio_keys))
      radio_decoder(sources:)
    }

    "checkbox" -> {
      use <- state.do(check_keys(checkbox_keys))
      checkbox_decoder(sources:)
    }

    "select" -> {
      use <- state.do(check_keys(select_keys))
      select_decoder(sources:)
    }

    unknown -> props.fail(report.new(error.UnknownKind(unknown)))
  }
}

fn data_decoder(sources sources: custom.Sources) -> Props(Kind) {
  use source <- props.get("source", {
    props.decode(_, {
      state.map(source.decoder(sources:), Ok)
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

fn radio_decoder(sources sources: custom.Sources) -> Props(Kind) {
  use layout <- props.try("layout", {
    zero.new(Row, decoder.from(layout_decoder()))
  })

  use options <- props.get("source", {
    props.decode(_, options.decoder(sources:))
  })

  props.succeed(Radio(choice: None, layout:, options:))
}

fn layout_decoder() -> decode.Decoder(Layout) {
  use string <- decode.then(decode.string)

  case string {
    "column" -> decode.success(Column)
    "row" -> decode.success(Row)
    _unknown -> decode.failure(Row, "layout")
  }
}

fn checkbox_decoder(sources sources: custom.Sources) -> Props(Kind) {
  use layout <- props.try("layout", {
    zero.new(Row, decoder.from(layout_decoder()))
  })

  use options <- props.get("source", {
    props.decode(_, options.decoder(sources:))
  })

  props.succeed(Checkbox([], layout:, options:))
}

fn select_decoder(sources sources: custom.Sources) -> Props(Kind) {
  use placeholder <- props.try("placeholder", {
    zero.option(decoder.from(decode.string))
  })

  use multiple <- props.try("multiple", zero.bool(decoder.from(decode.bool)))

  use options <- props.get("source", {
    props.decode(_, options.decoder(sources:))
  })

  use <- bool.guard(multiple, {
    props.succeed(MultiSelect([], placeholder:, options:))
  })

  props.succeed(Select(choice: None, placeholder:, options:))
}
