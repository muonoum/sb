import gleam/bool
import gleam/dict.{type Dict}
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pair
import gleam/result
import gleam/string
import lustre
import lustre/attribute.{type Attribute} as attr
import lustre/component
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import sb/extra/function.{apply, return}
import sb/extra/loadable.{type Loadable}
import sb/extra/reader.{type Reader}
import sb/extra/report.{type Report}
import sb/extra/reset
import sb/forms/choice
import sb/forms/condition
import sb/forms/debug
import sb/forms/error.{type Error}
import sb/forms/field.{type Field}
import sb/forms/kind
import sb/forms/layout
import sb/forms/scope.{type Scope}
import sb/forms/source.{type Source}
import sb/forms/task.{type Task}
import sb/forms/value.{type Value}
import sb/frontend/components/core
import sb/frontend/components/icons
import sb/frontend/components/sheet
import sb/frontend/fields/data
import sb/frontend/fields/input
import sb/frontend/fields/select
import sb/frontend/fields/text_input
import sb/frontend/portals

const search_debounce = 250

const change_debounce = 250

const field_row_style = [
  "relative group flex", "min-h-(--minimum-field-height) h-max", "last:grow",
  "border-b border-stone-300", "bg-white even:bg-stone-50",
  "last:border-b-0 [&:last-child>*]:pb-14",
]

const field_content_style = [
  "flex flex-col basis-4/6", "gap-2 shrink-0", "w-full h-min", "p-4 pb-6",
]

const field_meta_style = [
  "relative flex flex-col", "gap-4 grow py-4", "border-s border-stone-300",
  "break-all",
]

const field_padding_style = [
  "hidden group-last:flex z-[-1]", "fixed top-3/4 left-1/2 -translate-x-2/4",
  "w-(--sheet-width) h-screen", "bg-white group-even:bg-stone-50",
]

pub type LoadMessage =
  fn(Result(Task, Report(Error))) -> Message

pub type StepMessage =
  fn(Task, Scope) -> Message

pub opaque type Handlers {
  Handlers(
    load: fn(String, LoadMessage) -> Effect(Message),
    step: fn(Task, Scope, Dict(String, String), StepMessage) -> Effect(Message),
    schedule: fn(Int, Message) -> Effect(Message),
  )
}

pub opaque type Message {
  Load(String)
  Receive(Result(Task, Report(Error)))
  Change(field_id: String, value: Option(Value), delay: Int)
  ApplyChange(debounce: Int)
  Search(field_id: String, string: String)
  ApplySearch(field_id: String, debounce: Int)
  Evaluate
  Evaluated(Task, Scope)
  ResetForm
  StartJob
  ToggleDebug
  ToggleLayout
}

pub opaque type Model {
  Model(
    handlers: Handlers,
    debug: Bool,
    layout: Bool,
    state: Loadable(State, Report(Error)),
  )
}

type State {
  State(
    task: Task,
    scope: Scope,
    search: Dict(String, DebouncedSearch),
    debounce: Int,
    validated: Bool,
  )
}

type DebouncedSearch {
  DebouncedSearch(string: String, debounce: Int, applied: String)
}

pub fn app(
  load load: fn(String, LoadMessage) -> Effect(Message),
  step step: fn(Task, Scope, Dict(String, String), StepMessage) ->
    Effect(Message),
  schedule schedule: fn(Int, Message) -> Effect(Message),
) -> lustre.App(Nil, Model, Message) {
  let handlers = Handlers(load:, step:, schedule:)

  lustre.component(init: init(_, handlers), update:, view:, options: [
    // TODO: Denne trigger to ganger når siden lastes
    component.on_attribute_change("task-id", fn(string) {
      case string.trim(string) {
        "" -> Ok(Receive(report.error(error.BadId(""))))
        id -> Ok(Load(id))
      }
    }),
  ])
}

pub fn init(_flags, handlers: Handlers) -> #(Model, Effect(Message)) {
  let model = Model(handlers:, debug: True, layout: True, state: loadable.Empty)
  #(model, effect.none())
}

pub fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  let Model(handlers:, state:, ..) = model

  case message {
    Load(id) -> {
      let state = loadable.reload(state)
      #(Model(..model, state:), handlers.load(id, Receive))
    }

    Receive(Error(report)) -> {
      let state = loadable.fail(report, None)
      #(Model(..model, state:), effect.none())
    }

    Receive(Ok(task)) -> {
      let state =
        loadable.succeed({
          State(
            task:,
            scope: dict.new(),
            search: dict.new(),
            debounce: 0,
            validated: False,
          )
        })

      #(Model(..model, state:), step())
    }

    Change(field_id:, value:, delay:) -> {
      use state <- resolved(model)

      case task.update(state.task, field_id, value) {
        Error(_report) -> #(model, effect.none())

        Ok(task) if delay == 0 -> {
          let state = loadable.succeed(State(..state, task:))
          #(Model(..model, state:), step())
        }

        Ok(task) -> {
          let debounce = state.debounce + 1
          let state = loadable.succeed(State(..state, task:, debounce:))
          let model = Model(..model, state:)
          #(model, handlers.schedule(delay, ApplyChange(debounce)))
        }
      }
    }

    ApplyChange(debounce:) -> {
      use state <- resolved(model)
      use <- bool.guard(state.debounce != debounce, #(model, effect.none()))
      let state = loadable.succeed(State(..state, debounce: 0))
      #(Model(..model, state:), step())
    }

    Search(field_id:, string: "") -> {
      // TODO: Reset field placeholder
      use state <- resolved(model)
      let search = dict.delete(state.search, field_id)
      let state = loadable.succeed(State(..state, search:))
      #(Model(..model, state:), step())
    }

    Search(field_id:, string:) -> {
      use state <- resolved(model)

      let search = {
        use <- result.lazy_unwrap(dict.get(state.search, field_id))
        DebouncedSearch(string:, debounce: 0, applied: "")
      }

      let apply =
        ApplySearch(field_id, search.debounce + 1)
        |> handlers.schedule(search_debounce, _)

      let search =
        DebouncedSearch(..search, string:, debounce: search.debounce + 1)
        |> dict.insert(state.search, field_id, _)
      let state = loadable.succeed(State(..state, search:))
      #(Model(..model, state:), apply)
    }

    ApplySearch(field_id:, debounce:) -> {
      // TODO: Reset field placeholder
      use state <- resolved(model)

      case dict.get(state.search, field_id) {
        Ok(search) if search.debounce == debounce -> {
          let search =
            DebouncedSearch(..search, applied: search.string, debounce: 0)
            |> dict.insert(state.search, field_id, _)
          let state = loadable.succeed(State(..state, search:))
          #(Model(..model, state:), step())
        }

        _else -> #(model, effect.none())
      }
    }

    Evaluate -> {
      use State(task:, scope:, search:, ..) <- resolved(model)

      let search = {
        use _id, search <- dict.map_values(search)
        search.applied
      }

      let step = handlers.step(task, scope, search, Evaluated)
      #(model, step)
    }

    Evaluated(task, scope) -> {
      use state <- resolved(model)
      io.println(debug.inspect_scope(scope))
      let changed = scope != state.scope || task != state.task
      let state = loadable.succeed(State(..state, task:, scope:))
      let model = Model(..model, state:)
      use <- bool.guard(changed, #(model, step()))
      #(model, effect.none())
    }

    ResetForm ->
      case model.state {
        loadable.Loaded(_status, State(task:, ..)) -> {
          #(model, effect.from(apply(Load(task.id))))
        }

        _else -> #(model, event.emit("reset", json.null()))
      }

    StartJob -> #(model, effect.none())

    ToggleDebug -> #(Model(..model, debug: !model.debug), effect.none())

    ToggleLayout -> {
      #(Model(..model, layout: !model.layout), effect.none())
    }
  }
}

fn step() -> Effect(Message) {
  effect.from(apply(Evaluate))
}

fn resolved(model: Model, then: fn(State) -> #(Model, Effect(message))) {
  case model.state {
    loadable.Loaded(loadable.Resolved, state) -> then(state)
    _state -> #(model, effect.none())
  }
}

fn is_loading(source: Source, field_id: String, task: Task) -> Bool {
  use <- bool.guard(when: source.is_loading(source), return: True)
  use ref <- list.any(source.refs(source))
  use <- bool.guard(when: field_id == ref, return: False)

  case dict.get(task.fields, ref) {
    Ok(field) -> kind.is_loading(field.kind, is_loading(_, field_id, task))
    Error(Nil) -> False
  }
}

fn view(model: Model) -> Element(Message) {
  element.fragment([page_header(model), page(model)])
}

fn page_header(model: Model) -> Element(Message) {
  let validated = case model.state {
    loadable.Loaded(loadable.Resolved, State(validated:, ..)) -> validated
    _else -> False
  }

  portals.into_actions([
    html.div([attr.class("flex gap-5")], [
      core.button(button: [event.on_click(ResetForm)], label: [], body: [
        html.text("Nullstill skjema"),
      ]),
      core.button(
        button: [
          event.on_click(StartJob),
          attr.class("group"),
          attr.disabled(!validated),
        ],
        body: [html.text("Utfør oppgave")],
        label: [
          core.classes([
            "!no-underline transition-colors text-shadow-25 text-neutral-100",
            case validated {
              True -> "bg-emerald-600 group-hover:bg-emerald-700"
              False -> "bg-zinc-400"
            },
          ]),
        ],
      ),
    ]),
  ])
}

type Context {
  Context(debug: Bool, layout: Bool, state: State)
}

fn get_debug() -> Reader(Bool, Context) {
  use Context(debug:, ..) <- reader.bind(reader.ask)
  reader.return(debug)
}

fn get_layout() -> Reader(Bool, Context) {
  use Context(layout:, ..) <- reader.bind(reader.ask)
  reader.return(layout)
}

fn get_state() -> Reader(State, Context) {
  use Context(state:, ..) <- reader.bind(reader.ask)
  reader.return(state)
}

fn get_task() -> Reader(Task, Context) {
  use State(task:, ..) <- reader.bind(get_state())
  reader.return(task)
}

fn page(model: Model) -> Element(Message) {
  core.page([
    case model.state {
      loadable.Empty | loadable.Loading -> element.none()

      loadable.Failed(_status, report, _value) ->
        sheet.view(
          [attr.class("flex items-center")],
          header: [],
          body: [task_error(report)],
          padding: [],
        )

      loadable.Loaded(_status, State(task:, ..) as state) -> {
        let context = Context(debug: model.debug, layout: model.layout, state:)

        reader.run(context:, reader: {
          use header <- reader.bind(task_header())
          let description = core.maybe(task.description, task_description)
          use fields <- reader.bind(reader.map(task_fields(), element.fragment))

          reader.return(
            sheet.view([], header:, padding: [], body: [description, fields]),
          )
        })
      }
    },
  ])
}

fn task_error(report: Report(Error)) -> Element(message) {
  core.inspect([attr.class("p-6 text-2xl text-red-800")], report)
}

fn task_header() -> Reader(List(Element(Message)), Context) {
  use task <- reader.bind(get_task())
  use task_options <- reader.bind(task_options())

  reader.return([
    task_name(task.name),
    core.filler(),
    task_options,
    close_task(),
  ])
}

fn task_name(name: String) -> Element(message) {
  html.div([attr.class("text-lg font-bold self-center")], [html.text(name)])
}

fn task_options() -> Reader(Element(Message), Context) {
  use debug <- reader.bind(get_debug())
  use layout <- reader.bind(get_layout())
  use <- return(reader.return)

  html.div([core.classes(["flex gap-3 items-center p-1 rounded-sm"])], [
    case debug {
      True -> enabled_option(ToggleDebug, "hide debug", icons.eye_outline)

      False ->
        disabled_option(ToggleDebug, "show debug", icons.eye_slash_outline)
    },

    case layout {
      True -> enabled_option(ToggleLayout, "hide layout", icons.squares22)
      False -> disabled_option(ToggleLayout, "show layout", icons.squares22)
    },
  ])
}

fn enabled_option(
  message: message,
  title: String,
  element: fn(List(Attribute(message))) -> Element(message),
) -> Element(message) {
  html.div(
    [event.on_click(message), attr.class("cursor-pointer"), attr.title(title)],
    [element([])],
  )
}

fn disabled_option(
  message: message,
  title: String,
  element: fn(List(Attribute(message))) -> Element(message),
) -> Element(message) {
  html.div(
    [event.on_click(message), attr.class("cursor-pointer"), attr.title(title)],
    [element([attr.class("stroke-stone-600/60")])],
  )
}

fn close_task() -> Element(message) {
  html.a(
    [
      attr.href("/oppgaver"),
      attr.class("flex items-center p-2 rounded-sm"),
      attr.title("close form"),
    ],
    [icons.x_mark_outline([attr.class("stroke-2")])],
  )
}

fn task_description(description: String) -> Element(message) {
  html.div([attr.class("p-3 text-sm font-medium bg-zinc-800 text-zinc-300")], [
    html.text(description),
  ])
}

fn task_fields() -> Reader(List(Element(Message)), Context) {
  use task <- reader.bind(get_task())
  use layout <- reader.bind(get_layout())

  case task.layout, layout {
    layout, False -> results_layout(layout.results)
    layout.Ids(ids:, ..), _use_layout -> list_layout(ids)
    layout.Grid(areas:, style:, ..), _use_layout -> grid_layout(areas, style)
    layout.Results(results), _use_layout -> results_layout(results)
  }
}

fn list_layout(list: List(String)) -> Reader(List(Element(Message)), Context) {
  use task <- reader.bind(get_task())
  use <- return(results_layout)
  use id <- list.map(list)

  dict.get(task.fields, id)
  |> report.replace_error(error.BadId(id))
  |> result.replace(id)
}

fn grid_layout(
  _areas: List(String),
  _style: Dict(String, String),
) -> Reader(List(Element(Message)), Context) {
  // TODO
  reader.return([element.none()])
}

fn results_layout(
  layout: List(Result(String, Report(Error))),
) -> Reader(List(Element(Message)), Context) {
  use debug <- reader.bind(get_debug())
  use task <- reader.bind(get_task())
  use <- return(reader.sequence)
  use result <- list.map(layout)

  let field = {
    use id <- result.try(result)
    dict.get(task.fields, id)
    |> report.replace_error(error.BadId(id))
    |> result.map(pair.new(id, _))
  }

  case field {
    Error(report) ->
      html.div([core.classes(field_row_style)], [field_error(report)])
      |> reader.return

    Ok(#(id, field)) ->
      case condition.is_true(reset.unwrap(field.hidden)), debug {
        False, _debug -> field_container(id, field)
        True, False -> reader.return(element.none())
        True, True -> reader.map(field_container(id, field), hidden_field)
      }
  }
}

fn field_error(report: Report(Error)) -> Element(message) {
  html.div([attr.class("flex flex-col gap-2 shrink-0 w-full h-min p-4 pb-6")], [
    core.inspect([attr.class("text-red-800")], report),
  ])
}

fn hidden_field(content) -> Element(message) {
  html.div([], [content])
}

fn field_container(
  id: String,
  field: Field,
) -> Reader(Element(Message), Context) {
  use state <- reader.bind(get_state())
  let search = option.from_result(dict.get(state.search, id))
  use field_meta <- reader.bind(field_meta(id, field, search))
  use field_content <- reader.bind(field_content(id, field, search))
  use <- return(reader.return)
  [field_content, field_meta, field_padding()]
  |> html.div([core.classes(field_row_style)], _)
}

fn field_padding() -> Element(Message) {
  html.div([core.classes(field_padding_style)], [
    html.div([attr.class("basis-4/6")], []),
    html.div([attr.class("border-s border-stone-300")], []),
  ])
}

fn field_content(
  id: String,
  field: Field,
  search: Option(DebouncedSearch),
) -> Reader(Element(Message), Context) {
  use task <- reader.bind(get_task())
  let is_loading = is_loading(_, id, task)
  use field_kind <- reader.bind(field_kind(id, field, search, is_loading))
  use <- return(reader.return)

  html.div([core.classes(field_content_style)], [
    html.div([attr.class("flex flex-col gap-1.5 mb-1")], [
      core.maybe(field.label, field_label),
      core.maybe(field.description, field_description),
      field_kind,
    ]),
  ])
}

fn field_label(text: String) -> Element(message) {
  html.div([attr.class("font-semibold")], [html.text(text)])
}

fn field_description(text: String) -> Element(message) {
  html.div([attr.class("font-medium text-zinc-500 text-sm")], [html.text(text)])
}

fn field_meta(
  id: String,
  field: Field,
  search: Option(DebouncedSearch),
) -> Reader(Element(Message), Context) {
  use debug <- reader.bind(get_debug())
  use <- return(reader.return)

  html.div([core.classes(field_meta_style)], case debug {
    True -> field_debug(id, field, search)

    False -> [
      html.div([attr.class("font-semibold px-4")], [html.text(id)]),
      case field.value(field) {
        Some(Ok(_value)) | None -> element.none()

        Some(Error(report)) ->
          core.inspect([attr.class("px-4 text-red-800")], report)
      },
    ]
  })
}

fn field_debug(
  id: String,
  field: Field,
  search: Option(DebouncedSearch),
) -> List(Element(message)) {
  let sources = kind.sources(field.kind)
  let initial_sources = list.map(sources, reset.initial)

  [
    html.div([attr.class("font-semibold px-4")], [html.text(id)]),
    case initial_sources {
      initial if sources == initial -> element.none()

      [source] ->
        debug_source([attr.class("text-stone-800")], reset.unwrap(source))

      sources ->
        html.ul([attr.class("list-inside")], {
          use source <- list.map(sources)
          debug_sources([attr.class("text-stone-800")], reset.unwrap(source))
        })
    },
    case sources {
      [] -> element.none()

      [source] ->
        debug_source([attr.class("text-sky-800")], reset.unwrap(source))

      sources ->
        html.ul([attr.class("list-inside")], {
          use source <- list.map(sources)
          debug_sources([attr.class("text-sky-800")], reset.unwrap(source))
        })
    },
    case search {
      None -> element.none()
      Some(search) -> core.inspect([attr.class("px-4 text-pink-800")], search)
    },
    case field.value(field) {
      None -> element.none()

      Some(Ok(value)) ->
        core.inspect([attr.class("px-4 text-emerald-800")], value)

      Some(Error(report)) ->
        core.inspect([attr.class("px-4 text-red-800")], report)
    },
  ]
}

fn debug_source(
  attr: List(Attribute(message)),
  source: Result(Source, Report(Error)),
) -> Element(message) {
  case source {
    Error(report) -> core.inspect([attr.class("px-4 text-red-800")], report)
    Ok(source) -> core.inspect(list.append([attr.class("px-4")], attr), source)
  }
}

fn debug_sources(
  attr: List(Attribute(message)),
  source: Result(Source, Report(Error)),
) -> Element(message) {
  let attrs = list.append([attr.class("inline break-normal")], attr)

  case source {
    Error(report) ->
      html.li([attr.class("list-[square] px-4 mb-1 last:mb-0")], [
        core.inspect([attr.class("text-red-800 inline break-normal")], report),
      ])

    Ok(source) ->
      html.li([attr.class("list-[square] px-4 mb-1 last:mb-0")], [
        core.inspect(attrs, source),
      ])
  }
}

fn field_kind(
  id: String,
  field: Field,
  search: Option(DebouncedSearch),
  is_loading: fn(Source) -> Bool,
) -> Reader(Element(Message), Context) {
  use debug <- reader.bind(get_debug())
  use <- return(reader.return)

  let text_input_config = fn(placeholder) {
    text_input.Config(id:, placeholder:, input: fn(string) {
      Change(id, Some(value.String(string)), delay: change_debounce)
    })
  }

  let input_config = fn(layout, options) {
    input.Config(
      id:,
      layout:,
      options:,
      change: Change(id, _, delay: 0),
      debug:,
      is_loading:,
    )
  }

  let select_config = fn(placeholder, options) {
    let search_value = {
      use search <- option.map(search)
      search.string
    }

    let applied_search = {
      use search <- option.map(search)
      search.applied
    }

    select.Config(
      options:,
      placeholder:,
      is_loading:,
      search_value:,
      applied_search:,
      search: Search(id, _),
      clear_search: Search(id, ""),
      change: Change(id, _, delay: 0),
      debug:,
    )
  }

  case field.kind {
    kind.Data(source) ->
      data.field(data.Config(source: reset.unwrap(source), debug:, is_loading:))

    kind.Text(string:, placeholder:) ->
      text_input.text(string, text_input_config(placeholder))

    kind.Textarea(string:, placeholder:) ->
      text_input.textarea(string, text_input_config(placeholder))

    kind.Radio(selected, layout:, options:) ->
      input.radio(config: input_config(layout, options), selected: {
        option.map(selected, choice.key)
      })

    kind.Checkbox(selected, layout:, options:) ->
      input.checkbox(
        config: input_config(layout, options),
        selected: list.map(selected, choice.key),
      )

    kind.Select(selected, placeholder:, options:) ->
      select.select(
        config: select_config(placeholder, options),
        selected: option.map(selected, choice.key),
      )

    kind.MultiSelect(selected, placeholder:, options:) ->
      select.multi_select(
        config: select_config(placeholder, options),
        selected: list.map(selected, choice.key),
      )
  }
}
