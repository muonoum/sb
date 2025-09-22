import gleam/bool
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/set.{type Set}
import sb/extra/function.{identity, return}
import sb/extra/report.{type Report}
import sb/extra/reset.{type Reset}
import sb/extra/state
import sb/forms/choice.{type Choice}
import sb/forms/custom
import sb/forms/decoder
import sb/forms/error.{type Error}
import sb/forms/handlers.{type Handlers}
import sb/forms/options.{type Options}
import sb/forms/props
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

  Radio(selected: Option(Value), options: Options, layout: Layout)
  Select(selected: Option(Value), options: Options, placeholder: Option(String))
  Checkbox(selected: List(Value), options: Options, layout: Layout)

  MultiSelect(
    selected: List(Value),
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

pub fn is_loading(kind: Kind, check: fn(Source) -> Bool) -> Bool {
  case kind {
    Text(..) | Textarea(..) -> False

    Data(source) ->
      reset.unwrap(source)
      |> result.map(check)
      |> result.unwrap(False)

    Radio(options:, ..)
    | Select(options:, ..)
    | Checkbox(options:, ..)
    | MultiSelect(options:, ..) -> options.is_loading(options, check)
  }
}

pub fn reset(kind: Kind, refs: Set(String)) -> Kind {
  case kind {
    Text(..) | Textarea(..) -> kind
    Data(source:) -> Data(reset.maybe(source, refs))

    Radio(selected:, options:, ..) -> {
      let options = options.reset(options, refs)
      let selected = select_one(selected, options)
      Radio(..kind, selected:, options:)
    }

    Select(selected:, options:, ..) -> {
      let options = options.reset(options, refs)
      let selected = select_one(selected, options)
      Select(..kind, selected:, options:)
    }

    Checkbox(selected:, options:, ..) -> {
      let options = options.reset(options, refs)
      let selected = select_multiple(selected, options)
      Checkbox(..kind, selected:, options:)
    }

    MultiSelect(selected:, options:, ..) -> {
      let options = options.reset(options, refs)
      let selected = select_multiple(selected, options)
      MultiSelect(..kind, selected:, options:)
    }
  }
}

// TODO
fn select_one(selected: Option(Value), options: Options) -> Option(Value) {
  let selected = {
    use key <- option.map(selected)
    options.select(options, key)
    |> result.map(choice.key)
  }

  case selected {
    None | Some(Error(..)) -> None
    Some(Ok(choice)) -> Some(choice)
  }
}

// TODO
fn select_multiple(selected: List(Value), options: Options) -> List(Value) {
  let selected = {
    use key <- list.try_map(selected)
    options.select(options, key)
    |> result.map(choice.key)
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

    Radio(selected:, options:, layout:) ->
      options.evaluate(options, scope, search:, handlers:)
      |> Radio(selected:, options: _, layout:)

    Select(selected:, options:, placeholder:) ->
      options.evaluate(options, scope, search:, handlers:)
      |> Select(selected:, options: _, placeholder:)

    Checkbox(selected:, layout:, options:) ->
      options.evaluate(options, scope, search:, handlers:)
      |> Checkbox(selected:, options: _, layout:)

    MultiSelect(selected:, placeholder:, options:) ->
      options.evaluate(options, scope, search:, handlers:)
      |> MultiSelect(selected:, options: _, placeholder:)
  }
}

pub fn update(kind: Kind, value: Option(Value)) -> Result(Kind, Report(Error)) {
  case kind, value {
    Data(..), _value -> report.error(error.BadKind("data"))

    Text(..), None -> Ok(Text(..kind, string: ""))
    Textarea(..), None -> Ok(Textarea(..kind, string: ""))

    Text(..), Some(value.String(string)) -> Ok(Text(..kind, string:))
    Textarea(..), Some(value.String(string)) -> Ok(Textarea(..kind, string:))

    Text(..), Some(value) | Textarea(..), Some(value) ->
      report.error(error.BadValue(value))

    Radio(..), None -> Ok(Radio(..kind, selected: None))
    Select(..), None -> Ok(Select(..kind, selected: None))
    Checkbox(..), None -> Ok(Checkbox(..kind, selected: []))
    MultiSelect(..), None -> Ok(MultiSelect(..kind, selected: []))

    Radio(options:, ..), Some(key) -> {
      use selected <- result.try(
        options.select(options, key)
        |> result.map(choice.key),
      )

      Ok(Radio(..kind, selected: Some(selected), options:))
    }

    Select(options:, ..), Some(key) -> {
      use selected <- result.try(
        options.select(options, key)
        |> result.map(choice.key),
      )

      Ok(Select(..kind, selected: Some(selected), options:))
    }

    // TODO
    Checkbox(options:, ..), Some(value.List(keys)) -> {
      use selected <- result.try(
        list.try_map(keys, options.select(options, _))
        |> result.map(list.map(_, choice.key)),
      )

      Ok(Checkbox(..kind, selected:, options:))
    }

    Checkbox(..), Some(value) -> report.error(error.BadValue(value))

    // TODO
    MultiSelect(options:, ..), Some(value.List(keys)) -> {
      use selected <- result.try(
        list.try_map(keys, options.select(options, _))
        |> result.map(list.map(_, choice.key)),
      )

      Ok(MultiSelect(..kind, selected:, options:))
    }

    MultiSelect(..), Some(value) -> report.error(error.BadValue(value))
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

    // TODO
    Radio(Some(selected), options:, ..) | Select(Some(selected), options:, ..) ->
      options.select(options, selected)
      |> result.map(choice.value)
      |> Some

    Checkbox(selected:, options:, ..) | MultiSelect(selected:, options:, ..) ->
      list.try_map(selected, options.select(options, _))
      |> result.map(list.map(_, choice.value))
      |> result.map(value.List)
      |> Some
  }
}

pub fn decoder(
  name: String,
  sources sources: custom.Sources,
  then check_keys: fn(List(String)) -> props.Try(Nil),
) -> props.Try(Kind) {
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

    unknown -> state.error(report.new(error.UnknownKind(unknown)))
  }
}

fn data_decoder(sources sources: custom.Sources) -> props.Try(Kind) {
  use source <- props.get("source", {
    props.decode(_, source.reset_decoder(sources))
  })

  state.ok(Data(source:))
}

fn text_decoder() -> props.Try(Kind) {
  use placeholder <- props.try("placeholder", {
    zero.option(decoder.from(decode.string))
  })

  use string <- props.try("default", zero.string(decoder.from(decode.string)))
  state.ok(Text(string:, placeholder:))
}

fn textarea_decoder() -> props.Try(Kind) {
  use placeholder <- props.try("placeholder", {
    zero.option(decoder.from(decode.string))
  })

  use string <- props.try("default", zero.string(decoder.from(decode.string)))
  state.ok(Textarea(string:, placeholder:))
}

fn radio_decoder(sources sources: custom.Sources) -> props.Try(Kind) {
  use layout <- props.try("layout", {
    zero.new(Row, decoder.from(layout_decoder()))
  })

  use options <- props.get("source", props.decode(_, options.decoder(sources:)))
  use selected <- props.try("default", zero.option(select_default(options)))
  state.ok(Radio(selected:, layout:, options:))
}

fn layout_decoder() -> decode.Decoder(Layout) {
  use string <- decode.then(decode.string)

  case string {
    "column" -> decode.success(Column)
    "row" -> decode.success(Row)
    _unknown -> decode.failure(Row, "layout")
  }
}

fn checkbox_decoder(sources sources: custom.Sources) -> props.Try(Kind) {
  use layout <- props.try("layout", {
    zero.new(Row, decoder.from(layout_decoder()))
  })

  use options <- props.get("source", props.decode(_, options.decoder(sources:)))
  use selected <- props.try("default", zero.list(multi_select_default(options)))
  state.ok(Checkbox(selected:, layout:, options:))
}

fn select_decoder(sources sources: custom.Sources) -> props.Try(Kind) {
  use placeholder <- props.try("placeholder", {
    zero.option(decoder.from(decode.string))
  })

  use multiple <- props.try("multiple", zero.bool(decoder.from(decode.bool)))
  use options <- props.get("source", props.decode(_, options.decoder(sources:)))
  use <- bool.lazy_guard(multiple, multi_select_decoder(placeholder, options))
  use selected <- props.try("default", zero.option(select_default(options)))
  state.ok(Select(selected:, placeholder:, options:))
}

fn multi_select_decoder(
  placeholder: Option(String),
  options: Options,
) -> fn() -> props.Try(Kind) {
  use <- identity
  use selected <- props.try("default", zero.list(multi_select_default(options)))
  state.ok(MultiSelect(selected:, placeholder:, options:))
}

fn select_default(
  options: Options,
) -> fn(Dynamic) -> Result(Value, Report(Error)) {
  use dynamic <- identity
  use value <- result.try(decoder.run(dynamic, value.decoder()))
  options.select(options, value)
  |> result.map(choice.key)
}

fn multi_select_default(
  options: Options,
) -> fn(Dynamic) -> Result(List(Value), Report(Error)) {
  use dynamic <- identity
  use values <- result.try(decoder.run(dynamic, decode.list(value.decoder())))
  use value <- list.try_map(values)
  options.select(options, value)
  |> result.map(choice.key)
}
