import gleam/bool
import gleam/dynamic/decode.{type Decoder}
import gleam/int
import gleam/list
import gleam/option.{type Option, Some}
import gleam/set
import gleam/string
import lustre/attribute as attr
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import lustre/server_component as server
import sb/extra/function.{compose, identity, return}
import sb/extra/reader.{type Reader}
import sb/extra/report
import sb/extra/reset
import sb/forms/error
import sb/forms/kind
import sb/forms/options.{type Options}
import sb/forms/source.{type Source}
import sb/forms/value.{type Value}
import sb/frontend/components/core

pub type Config(message) {
  Config(
    id: String,
    options: Options,
    layout: kind.Layout,
    is_loading: fn(Source) -> Bool,
    change: fn(Option(Value)) -> message,
    debug: Bool,
  )
}

pub opaque type Context(message) {
  Context(
    kind: String,
    group_index: Int,
    is_selected: fn(Value) -> Bool,
    change: fn(Value) -> Decoder(message),
    config: Config(message),
  )
}

fn checked_decoder() -> Decoder(Bool) {
  decode.at(["target", "checked"], decode.bool)
}

fn get_context() -> Reader(Context(message), Context(message)) {
  use context <- reader.bind(reader.ask)
  reader.return(context)
}

fn with_group_index(
  reader: Reader(v, Context(message)),
  group_index: Int,
) -> Reader(v, Context(message)) {
  use context <- reader.local(reader)
  Context(..context, group_index:)
}

fn get_config() -> Reader(Config(message), Context(message)) {
  use Context(config:, ..) <- reader.bind(get_context())
  reader.return(config)
}

pub fn radio(
  selected selected: Option(Value),
  config config: Config(message),
) -> Element(message) {
  let is_selected = fn(key) { Some(key) == selected }
  let change = fn(key) { decode.success(config.change(Some(key))) }

  let context =
    Context(kind: "radio", group_index: 0, is_selected:, change:, config:)

  reader.run(field(), context:)
}

pub fn checkbox(
  selected selected: List(Value),
  config config: Config(message),
) -> Element(message) {
  let is_selected = set.contains(set.from_list(selected), _)

  let select = fn(key) {
    use <- identity
    let set = set.from_list(selected)
    use <- bool.guard(set.contains(set, key), selected)
    list.append(selected, [key])
  }

  let change = fn(key) {
    use checked <- decode.then(checked_decoder())
    use <- return(compose(config.change, decode.success))
    use <- return(compose(value.List, Some))
    use <- bool.lazy_guard(checked, select(key))
    use have <- list.filter(selected)
    key != have
  }

  let context =
    Context(config:, kind: "checkbox", group_index: 0, is_selected:, change:)

  reader.run(field(), context:)
}

fn field() -> Reader(Element(message), Context(message)) {
  use config <- reader.bind(get_config())

  // TODO: Gjør keys her og igjen lenger ned
  case options.unique_keys(config.options) {
    Error(report) ->
      core.inspect([attr.class("text-red-800")], report)
      |> reader.return

    Ok(_keys) -> {
      use choices <- reader.bind(case config.options {
        options.SingleSource(source) ->
          [group_source(source)]
          |> reader.sequence

        options.SourceGroups(groups) -> {
          use <- return(reader.sequence)
          use group, group_index <- list.index_map(groups)
          let options.Group(label:, source:) = group
          use <- return(with_group_index(_, group_index))
          use group_source <- reader.bind(group_source(source))

          element.fragment([group_label(label), group_source])
          |> reader.return
        }
      })

      html.div([], choices)
      |> reader.return
    }
  }
}

fn group_label(text: String) -> Element(message) {
  html.div([attr.class("font-semibold first:mt-1 mt-4 mb-1")], [html.text(text)])
}

fn group_source(
  source: source.Resetable,
) -> Reader(Element(message), Context(message)) {
  use config <- reader.bind(get_config())

  case reset.unwrap(source), config.debug {
    Error(report), _debug ->
      core.inspect([attr.class("text-red-800")], report)
      |> reader.return

    Ok(source.Literal(value)), _debug -> group_members(value)

    Ok(source), False ->
      reader.return(
        html.div([attr.class("flex gap-2 justify-center")], [
          core.spinner([], config.is_loading(source)),
        ]),
      )

    Ok(source), True ->
      reader.return(
        html.div([attr.class("flex gap-2")], [
          core.inspect([], source),
          core.spinner([], config.is_loading(source)),
        ]),
      )
  }
}

fn group_members(value: Value) -> Reader(Element(message), Context(message)) {
  use Context(group_index:, ..) <- reader.bind(get_context())
  use config <- reader.bind(get_config())

  let keys =
    value.keys(value)
    |> report.replace_error(error.BadValue(value))

  case keys {
    Error(report) ->
      core.inspect([attr.class("text-red-800")], report)
      |> reader.return

    Ok(keys) -> {
      use choices <- reader.bind({
        use <- return(reader.sequence)
        use key, item_index <- list.index_map(keys)

        group_choice(key, {
          [int.to_string(group_index), int.to_string(item_index), config.id]
          |> string.join("-")
        })
      })

      let attr = [
        attr.class("flex flex-wrap"),
        case config.layout {
          kind.Column -> attr.class("flex-col w-fit")
          kind.Row -> attr.class("flex-row")
        },
      ]

      html.div(attr, choices)
      |> reader.return
    }
  }
}

fn group_choice(
  key: Value,
  dom_id: String,
) -> Reader(Element(message), Context(message)) {
  use context <- reader.bind(get_context())
  use config <- reader.bind(get_config())
  use <- return(reader.return)
  let change = event.on("change", context.change(key))

  let input =
    html.input([
      attr.id(dom_id),
      attr.name(config.id),
      attr.type_(context.kind),
      attr.class("p-1 accent-cyan-800 translate-y-px"),
      server.include(change, ["target.checked"]),
      case context.is_selected(key) {
        True -> attr.attribute("checked", "true")
        False -> attr.none()
      },
    ])

  html.label(
    [attr.for(dom_id), attr.class("flex items-baseline ps-0 pe-3 py-1 gap-2")],
    [input, html.div([], [core.inline_value(key)])],
  )
}
