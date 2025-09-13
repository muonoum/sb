import gleam/bool
import gleam/dict.{type Dict}
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
import sb/extra/function.{apply}
import sb/extra/loadable.{type Loadable, Loaded, Resolved}
import sb/extra/report.{type Report}
import sb/extra/reset
import sb/forms/condition
import sb/forms/error.{type Error}
import sb/forms/field.{type Field}
import sb/forms/kind
import sb/forms/source.{type Source}
import sb/forms/task.{type Task}
import sb/frontend/components/core
import sb/frontend/components/icons
import sb/frontend/components/sheet
import sb/frontend/portals

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

type Loader =
  fn(Result(Task, Report(Error))) -> Message

pub opaque type Handlers {
  Handlers(
    load: fn(String, Loader) -> Effect(Message),
    step: fn(Task, Dict(String, String), Loader) -> Effect(Message),
    schedule: fn(Int, Message) -> Effect(Message),
  )
}

pub opaque type Message {
  Load(String)
  Receive(Result(Task, Report(Error)))
  ResetForm
  StartJob
  Evaluate
  ToggleDebug
}

pub opaque type Model {
  Model(handlers: Handlers, debug: Bool, state: Loadable(State, Report(Error)))
}

type State {
  State(
    task: Task,
    search: Dict(String, Search),
    debounce: Int,
    validated: Bool,
  )
}

type Search {
  Search(value: String, debounce: Int, applied: String)
}

pub fn app(
  load load: fn(String, Loader) -> Effect(Message),
  step step: fn(Task, Dict(String, String), Loader) -> Effect(Message),
  schedule schedule: fn(Int, Message) -> Effect(Message),
) -> lustre.App(Nil, Model, Message) {
  let handlers = Handlers(load:, step:, schedule:)

  lustre.component(init: init(_, handlers), update:, view:, options: [
    component.on_attribute_change("task-id", fn(string) {
      case string.trim(string) {
        "" -> Ok(Receive(report.error(error.BadId(""))))
        id -> Ok(Load(id))
      }
    }),
  ])
}

pub fn init(_flags, handlers: Handlers) -> #(Model, Effect(Message)) {
  #(Model(handlers:, debug: False, state: loadable.Initial), effect.none())
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
          State(task:, search: dict.new(), debounce: 0, validated: False)
        })

      #(Model(..model, state:), dispatch_evaluate())
    }

    ResetForm ->
      case model.state {
        Loaded(_status, State(task:, ..)) -> {
          #(model, effect.from(apply(Load(task.id))))
        }

        _else -> #(model, event.emit("reset", json.null()))
      }

    StartJob -> #(model, effect.none())

    Evaluate -> #(model, effect.none())

    ToggleDebug -> #(Model(..model, debug: !model.debug), effect.none())
  }
}

fn dispatch_evaluate() -> Effect(Message) {
  effect.from(apply(Evaluate))
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
    Loaded(Resolved, State(validated:, ..)) -> validated
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

fn page(model: Model) -> Element(Message) {
  core.page([
    case model.state {
      loadable.Initial | loadable.Loading -> element.none()

      loadable.Failed(_status, report, _value) ->
        sheet.view(
          [attr.class("flex items-center")],
          header: [],
          body: [task_error(report)],
          padding: [],
        )

      loadable.Loaded(_status, State(task:, ..) as state) ->
        sheet.view([], header: task_header(model, state), padding: [], body: [
          core.maybe(task.description, task_description),
          element.fragment(task_fields(model, state)),
        ])
    },
  ])
}

fn task_error(report: Report(Error)) -> Element(message) {
  core.inspect([attr.class("p-6 text-2xl text-red-800")], report)
}

fn task_header(model: Model, state: State) -> List(Element(Message)) {
  [task_name(state.task), core.filler(), task_debug(model.debug), close_task()]
}

fn task_name(task: Task) -> Element(message) {
  html.div([attr.class("text-lg font-bold self-center")], [html.text(task.name)])
}

fn task_debug(debug: Bool) -> Element(Message) {
  html.div([core.classes(["flex gap-3 items-center p-1 rounded-sm"])], [
    case debug {
      True ->
        icons.eye_outline([
          event.on_click(ToggleDebug),
          attr.class("cursor-pointer duration-75 transition-colors"),
        ])

      False ->
        icons.eye_slash_outline([
          event.on_click(ToggleDebug),
          attr.class("cursor-pointer stroke-stone-600/70"),
        ])
    },
  ])
}

fn close_task() -> Element(message) {
  html.a(
    [attr.href("/oppgaver"), attr.class("flex items-center p-2 rounded-sm")],
    [icons.x_mark_outline([attr.class("stroke-2")])],
  )
}

fn task_description(description: String) -> Element(message) {
  html.div([attr.class("p-3 text-sm font-medium bg-zinc-800 text-zinc-300")], [
    html.text(description),
  ])
}

fn task_fields(model: Model, state: State) -> List(Element(Message)) {
  let State(task:, ..) = state
  results_layout(task.layout, model, state)
}

fn results_layout(
  layout: List(Result(String, Report(Error))),
  model: Model,
  state: State,
) -> List(Element(Message)) {
  let State(task:, ..) = state
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

    Ok(#(id, field)) ->
      case condition.is_true(reset.unwrap(field.hidden)), model.debug {
        False, _debug -> field_container(id, field, model, state)
        True, True -> hidden_field(field_container(id, field, model, state))
        True, False -> element.none()
      }
  }
}

fn field_error(report: Report(Error)) -> Element(message) {
  html.div([attr.class("flex flex-col gap-2 shrink-0 w-full h-min p-4 pb-6")], [
    core.inspect([attr.class("text-red-800")], report),
  ])
}

fn hidden_field(content: Element(message)) -> Element(message) {
  html.div([], [content])
}

fn field_container(
  id: String,
  field: Field,
  model: Model,
  state: State,
) -> Element(Message) {
  let search =
    dict.get(state.search, id)
    |> option.from_result

  html.div([core.classes(field_row_style)], [
    field_content(id, field, search, state),
    field_meta(id, field, search, model),
    field_padding(),
  ])
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
  search: Option(Search),
  state: State,
) -> Element(Message) {
  let is_loading = is_loading(_, id, state.task)

  html.div([core.classes(field_content_style)], [
    html.div([attr.class("flex flex-col gap-1.5 mb-1")], [
      core.maybe(field.label, field_label),
      core.maybe(field.description, field_description),
      field_kind(id, field, search, is_loading, state),
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
  search: Option(Search),
  model: Model,
) -> Element(Message) {
  html.div([core.classes(field_meta_style)], case model.debug {
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
  search: Option(Search),
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
  _field: Field,
  _search: Option(Search),
  _is_loading: fn(Source) -> Bool,
  _state: State,
) -> Element(Message) {
  element.text(id)
}
