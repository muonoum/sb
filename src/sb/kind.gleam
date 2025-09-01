import extra
import extra/state
import gleam/bool
import gleam/dict
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/set.{type Set}
import sb/choice.{type Choice}
import sb/custom
import sb/decoder
import sb/error.{type Error}
import sb/handlers.{type Handlers}
import sb/options.{type Options}
import sb/props.{type Props}
import sb/report.{type Report}
import sb/reset.{type Reset}
import sb/scope.{type Scope}
import sb/source.{type Source}
import sb/value.{type Value}

pub const data_keys = ["source"]

pub const text_keys = ["default", "placeholder"]

pub const textarea_keys = ["default", "placeholder"]

pub const radio_keys = ["default", "layout", "source"]

pub const checkbox_keys = ["default", "layout", "source"]

pub const select_keys = ["default", "multiple", "placeholder", "source"]

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
  fields: custom.Fields,
  check_keys: fn(List(String)) -> Props(Nil),
) -> Props(Kind) {
  use name <- props.field("kind", decoder.new(decode.string))
  let context = report.context(_, error.BadKind(name))
  use <- extra.return(state.map_error(_, context))

  use <- result.lazy_unwrap({
    use custom <- result.map(dict.get(fields.custom, name))
    use <- state.do(state.update(dict.merge(_, custom)))
    decoder(fields, check_keys)
  })

  case name {
    "data" -> kind_decoder(data_decoder(), check_keys(data_keys))
    "text" -> kind_decoder(text_decoder(), check_keys(text_keys))
    "textarea" -> kind_decoder(textarea_decoder(), check_keys(textarea_keys))
    "radio" -> kind_decoder(radio_decoder(), check_keys(radio_keys))
    "checkbox" -> kind_decoder(checkbox_decoder(), check_keys(checkbox_keys))
    "select" -> kind_decoder(select_decoder(), check_keys(select_keys))
    unknown -> props.fail(report.new(error.UnknownKind(unknown)))
  }
}

fn kind_decoder(decoder: Props(kind), check_keys: Props(Nil)) -> Props(kind) {
  use <- state.do(check_keys)
  decoder
}

fn data_decoder() -> Props(Kind) {
  use source <- props.field("source", props.decode(_, source.decoder()))
  props.succeed(Data(reset.try_new(Ok(source), source.refs)))
}

fn text_decoder() -> Props(Kind) {
  props.succeed(Text(""))
}

fn textarea_decoder() -> Props(Kind) {
  props.succeed(Textarea(""))
}

fn radio_decoder() -> Props(Kind) {
  use options <- props.field("source", props.decode(_, options.decoder()))
  props.succeed(Select(None, options:))
}

fn checkbox_decoder() -> Props(Kind) {
  use options <- props.field("source", props.decode(_, options.decoder()))
  props.succeed(MultiSelect([], options:))
}

fn select_decoder() -> Props(Kind) {
  use multiple <- props.default_field("multiple", Ok(False), {
    decoder.new(decode.bool)
  })

  use options <- props.field("source", props.decode(_, options.decoder()))
  use <- bool.guard(multiple, props.succeed(MultiSelect([], options:)))
  props.succeed(Select(None, options:))
}
