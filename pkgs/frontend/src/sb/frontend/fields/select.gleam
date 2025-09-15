import gleam/bool
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/set
import lustre/attribute as attr
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import sb/extra
import sb/extra/function.{compose, return}
import sb/extra/reader.{type Reader}
import sb/extra/report.{type Report}
import sb/extra/reset.{type Reset}
import sb/forms/error.{type Error}
import sb/forms/options.{type Options}
import sb/forms/source.{type Source}
import sb/forms/value.{type Value}
import sb/frontend/components/core
import sb/frontend/components/search

pub const select_style = [
  "relative flex flex-col rounded-md", "border border-stone-900/30",
  "transition-[border-color,outline] duration-200 outline-transparent",
  "focus-within:outline focus-within:outline-4 focus-within:outline-offset-0",
  "focus-within:border-stone-950/60 focus-within:outline-stone-900/20",
]

const select_selected_container_style = [
  "flex flex-col gap-2", "px-3 py-2", "rounded-t-md", "font-medium text-sm",
  "border-b border-b-1", "bg-stone-100 border-stone-500/30",
]

const select_selected_style = [
  "group relative", "py-1", "cursor-pointer", "select-none",
  "hover:line-through",
]

const select_search_style = [
  "bg-white placeholder-zinc-500/80", "transition-[filter] duration-100",
  "grow px-3 py-2 z-[100] w-full", "outline outline-0", "border-0 shadow-inner",
  "group-first/input:rounded-md group-first/input:rounded-b-none",
  "group-last/input:rounded-b-md",
]

// const select_empty_style = [
//   "flex relative justify-center p-3", "font-medium text-3xl text-stone-500",
//   "border-t border-t-1 border-stone-500/30",
// ]

const select_options_style = [
  "flex flex-col grow overflow-y-auto", "w-full min-h-20 max-h-96",
  "rounded-b-md border-t border-t-1",
  "bg-white border-stone-500/30 outline-transparent",
]

const select_choice_style = [
  "py-1 px-3 py-2.5 text-sm first:pt-3 last:pb-3",
  "relative flex cursor-pointer hover:underline",
  "transition-[background-color] duration-100",
  "border-b last:border-b-0 border-stone-900/10",
]

const select_selected_choice_style = [
  "py-1 px-3 py-2.5 text-sm first:pt-3 last:pb-3", "relative flex text-zinc-500",
  "transition-[background-color] duration-100",
  "border-b last:border-b-0 border-stone-900/10",
]

// search?
// - "search member & .."
// - "search > member & .."

// TODO: For generisk for denne modulen?
fn has_placeholder(source: Reset(Result(Source, Report(Error)))) -> Bool {
  case reset.unwrap(reset.initial(source)) {
    Error(_report) -> False
    Ok(_source) -> False
  }
}

pub type Config(message) {
  Config(
    options: Options,
    placeholder: Option(String),
    is_loading: fn(Source) -> Bool,
    search_value: Option(String),
    applied_search: Option(String),
    search: fn(String) -> message,
    clear_search: message,
    change: fn(Option(Value)) -> message,
    debug: Bool,
  )
}

pub opaque type Context(message) {
  Context(
    config: Config(message),
    is_selected: fn(Value) -> Bool,
    select: fn(Value) -> message,
    deselect: fn(Value) -> message,
  )
}

fn get_context() -> Reader(Context(message), Context(message)) {
  reader.bind(reader.ask, reader.return)
}

fn get_config() -> Reader(Config(message), Context(message)) {
  use Context(config:, ..) <- reader.bind(get_context())
  reader.return(config)
}

pub fn select(
  selected selected: Option(Value),
  config config: Config(message),
) -> Element(message) {
  let context =
    Context(
      config:,
      is_selected: fn(key) { Some(key) == selected },
      select: fn(key) { config.change(Some(key)) },
      deselect: fn(_choice) { config.change(None) },
    )

  use <- return(reader.run(_, context:))
  use <- field()
  use <- return(reader.return)

  case selected {
    None -> element.none()

    Some(key) ->
      html.div([core.classes(select_selected_container_style)], [
        html.ul([attr.class("flex flex-col")], [
          html.li(
            [
              core.classes(select_selected_style),
              event.on_click(config.change(None)),
            ],
            [core.inline_value(key)],
          ),
        ]),
      ])
  }
}

pub fn multi_select(
  selected selected: List(Value),
  config config: Config(message),
) -> Element(message) {
  let context =
    Context(
      config:,
      is_selected: fn(key) {
        set.from_list(selected)
        |> set.contains(key)
      },
      select: fn(key) -> message {
        config.change({
          use <- return(compose(value.List, Some))
          let set = set.from_list(selected)
          use <- bool.guard(set.contains(set, key), selected)
          list.append(selected, [key])
        })
      },
      deselect: fn(key) {
        config.change({
          use <- return(compose(value.List, Some))
          use have <- list.filter(selected)
          key != have
        })
      },
    )

  use <- return(reader.run(_, context:))
  use <- field()
  use <- return(reader.return)

  case selected {
    [] -> element.none()

    selected ->
      html.div([core.classes(select_selected_container_style)], [
        html.ul([attr.class("flex flex-col ps-2")], {
          use key <- list.map(selected)

          html.li(
            [
              attr.class("list-[square]"),
              core.classes(select_selected_style),
              event.on_click(context.deselect(key)),
            ],
            [core.inline_value(key)],
          )
        }),
      ])
  }
}

fn field(
  selected: fn() -> Reader(Element(message), Context(message)),
) -> Reader(Element(message), Context(message)) {
  use selected <- reader.bind(selected())
  use search <- reader.bind(search())
  use options <- reader.bind(options())
  use <- return(reader.return)
  html.div([core.classes(select_style)], [selected, search, options])
}

fn search() -> Reader(Element(message), Context(message)) {
  use config <- reader.bind(get_config())
  use <- return(reader.return)

  html.div(
    [attr.class("group/input first:rounded-t-md last:rounded-b-md relative")],
    [
      html.input([
        core.classes(select_search_style),
        option.map(config.placeholder, attr.placeholder)
          |> option.lazy_unwrap(attr.none),
        event.on_input(config.search),
        option.unwrap(config.search_value, "")
          |> attr.value,
      ]),
      search.icon(
        [attr.class("right-[1px] top-[1px] z-[101]")],
        option.unwrap(config.search_value, ""),
        config.clear_search,
      ),
    ],
  )
}

fn options() -> Reader(Element(message), Context(message)) {
  use config <- reader.bind(get_config())

  use options <- reader.bind(case config.options {
    options.SingleSource(source) -> group_source(label: None, source:)

    options.SourceGroups(groups) -> {
      use <- return(reader.map(_, element.fragment))
      use <- return(reader.sequence)
      use options.Group(label:, source:) <- list.map(groups)
      group_source(Some(label), source:)
    }
  })

  html.div([core.classes(select_options_style)], [options])
  |> reader.return
}

fn group_label(label: Option(String)) -> Element(message) {
  use text <- core.maybe(label)
  html.div([attr.class("font-semibold px-3 py-2 mt-4 first:mt-0 pb-1")], [
    element.text(text),
  ])
}

fn group_source(
  label label: Option(String),
  source source: Reset(Result(Source, Report(Error))),
) -> Reader(Element(message), Context(message)) {
  use config <- reader.bind(get_config())

  let return = fn(element) {
    reader.return(element.fragment([group_label(label), element]))
  }

  case reset.unwrap(source), config.debug {
    Ok(source.Literal(value)), _debug ->
      group_value(label, value, has_placeholder(source))

    Error(report), _debug ->
      return(core.inspect([attr.class("p-3 text-red-800")], report))

    // TODO: Loading
    Ok(source), False ->
      return(html.div([attr.class("p-3")], [core.inspect([], source)]))

    Ok(source), True ->
      return(html.div([attr.class("p-3")], [core.inspect([], source)]))
  }
}

fn group_value(
  label: Option(String),
  value: Value,
  has_placeholder: Bool,
) -> Reader(Element(message), Context(message)) {
  case error.unique_keys(value), has_placeholder {
    Ok(keys), False -> {
      use keys <- reader.bind(find(label, keys))
      group_members(label, keys)
    }

    // TODO 
    Ok(keys), True -> group_members(label, keys)

    Error(report), _has_placeholder ->
      core.inspect([attr.class("p-3 text-red-800")], report)
      |> reader.return
  }
}

fn find(label: Option(String), keys: List(Value)) {
  use config <- reader.bind(get_config())
  let words = option.map(config.applied_search, extra.words)
  use <- return(reader.return)

  let match = fn(words) {
    use keys, word <- list.fold(words, keys)
    list.filter(keys, value.match(_, word))
  }

  case option.map(label, value.String), words {
    _label, None -> keys
    None, Some(words) -> match(words)

    Some(label), Some(words) ->
      case list.any(words, value.match(label, _)) {
        False -> match(words)
        True -> keys
      }
  }
}

fn group_members(
  label: Option(String),
  keys: List(Value),
) -> Reader(Element(a), Context(a)) {
  use context <- reader.bind(get_context())
  use <- return(reader.return)
  use <- bool.lazy_guard(keys == [], element.none)

  element.fragment([
    group_label(label),
    element.fragment({
      use key <- list.map(keys)

      let attr = case context.is_selected(key) {
        True -> [core.classes(select_selected_choice_style)]

        False -> [
          event.on_click(context.select(key)),
          core.classes(select_choice_style),
        ]
      }

      html.div(attr, [core.inline_value(key)])
    }),
  ])
}
