import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute as attr
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import sb/extra/function.{return}
import sb/extra/reader.{type Reader}
import sb/extra/report.{type Report}
import sb/extra/reset.{type Reset}
import sb/forms/check
import sb/forms/error.{type Error}
import sb/forms/options.{type Options}
import sb/forms/source.{type Source}
import sb/forms/value.{type Value}
import sb/frontend/components/core
import sb/frontend/components/search

pub const select_style = [
  "relative flex flex-col rounded-md", "border border-stone-900/30",
  "transition-[border-color,outline] duration-200",
  "focus-within:outline focus:outline-4 focus-within:outline-offset-0",
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
  "grow px-3 py-2 z-[100] w-full", "outline outline-0", "border-0",
  "shadow-inner",
  "group-first/input:rounded-md group-first/input:rounded-b-none",
  "group-last/input:rounded-b-md",
]

// TODO
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
    Ok(_source) -> todo
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
    select: fn(Value) -> message,
    debug: Bool,
  )
}

pub opaque type Context(message) {
  Context(config: Config(message))
}

fn get_context() -> Reader(Context(message), Context(message)) {
  use context <- reader.bind(reader.ask)
  reader.return(context)
}

fn get_config() -> Reader(Config(message), Context(message)) {
  use Context(config:) <- reader.bind(get_context())
  reader.return(config)
}

pub fn select(selected _selected, config config) {
  let context = Context(config:)

  use <- return(reader.run(_, context:))
  use <- field()

  // TODO: Har allerede context og config her; kanskje droppe reader
  // use config <- reader.bind(get_config())
  reader.return(element.none())
}

pub fn multi_select(selected _selected, config _config) {
  todo
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
      use <- return(reader.map(_, list.flatten))
      use <- return(reader.sequence)
      use options.Group(label:, source:) <- list.map(groups)
      group_source(Some(label), source:)
    }
  })

  html.div([core.classes(select_options_style)], options)
  |> reader.return
}

fn group_source(
  label _label: Option(String),
  source source: Reset(Result(Source, Report(Error))),
) -> Reader(List(Element(message)), Context(message)) {
  use config <- reader.bind(get_config())
  use <- return(reader.return)

  case reset.unwrap(source), config.debug {
    Error(_report), _debug -> todo

    Ok(source.Literal(value)), _debug ->
      group_value(value, has_placeholder(source))

    Ok(_source), False -> todo
    Ok(_source), True -> todo
  }

  [element.none()]
}

fn group_value(value: Value, has_placeholder: Bool) {
  case check.unique_keys(value), has_placeholder {
    Error(_report), _has_placeholder -> todo
    Ok(_keys), True -> todo
    Ok(_keys), False -> todo
  }
}
