import gleam/list
import gleam/option
import lustre
import lustre/attribute as attr
import lustre/component
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import sb/extra/function.{apply}
import sb/extra/loadable.{type Loadable}
import sb/extra/report.{type Report}
import sb/extra/string as string_extra
import sb/extra/tree.{type Tree}
import sb/extra/tree/zipper.{type Zipper}
import sb/extra/visibility.{Hidden, Visible}
import sb/forms/error.{type Error}
import sb/forms/nodes.{type Node}
import sb/forms/task.{type Task}
import sb/frontend/components/core

const flex_layout = [
  "flex flex-row flex-wrap items-start justify-center gap-6",
  "mx-auto max-w-(--tasks-width) p-(--page-margin)",
]

const grid_layout = [
  "justify-center flex-wrap mx-auto ", "max-w-(--tasks-width) p-(--page-margin)",
  "flex supports-[grid-template-rows:masonry]:grid",
  "[grid-template-columns:repeat(auto-fill,minmax(300px,1fr))]",
  "grid-rows-[masonry] gap-6 auto-cols-min",
]

pub type LoadMessage =
  fn(List(Task)) -> Message

pub opaque type Handlers {
  Handlers(
    schedule: fn(Message) -> Effect(Message),
    load: fn(LoadMessage) -> Effect(Message),
  )
}

pub opaque type Model {
  Model(
    handlers: Handlers,
    nodes: Loadable(Zipper(Node), Report(Error)),
    search: String,
  )
}

pub opaque type Message {
  Load
  Receive(List(Task))
  SearchReceived(String)
}

pub fn app(
  schedule schedule: fn(Message) -> Effect(Message),
  load load: fn(LoadMessage) -> Effect(Message),
) -> lustre.App(Nil, Model, Message) {
  let handlers = Handlers(schedule:, load:)

  lustre.component(init(_, handlers), update, view, options: [
    component.on_attribute_change("search", fn(string) {
      Ok(SearchReceived(string))
    }),
  ])
}

fn init(_flags, handlers: Handlers) -> #(Model, Effect(Message)) {
  let model = Model(handlers:, nodes: loadable.Empty, search: "")
  #(model, effect.from(apply(Load)))
}

fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  let Model(handlers:, ..) = model

  case message, model.nodes {
    Load, nodes -> {
      let nodes = loadable.reload(nodes)
      #(Model(..model, nodes:), handlers.load(Receive))
    }

    Receive(tasks), _nodes -> {
      let nodes = loadable.succeed(select(nodes.new(tasks), model.search))
      #(Model(..model, nodes:), handlers.schedule(Load))
    }

    SearchReceived(search), nodes -> {
      let nodes = loadable.map(nodes, select(_, search))
      #(Model(..model, search:, nodes:), effect.none())
    }
  }
}

fn select(nodes: Zipper(Node), search: String) -> Zipper(Node) {
  let words = string_extra.words(search)
  use nodes <- nodes.map(nodes)
  list.fold(words, nodes, nodes.select)
}

fn view(model: Model) -> Element(Message) {
  core.page(case model.nodes {
    loadable.Empty -> [element.none()]
    loadable.Loading -> [element.none()]
    loadable.Failed(_status, report, _value) -> [core.inspect([], report)]
    loadable.Loaded(_status, nodes) -> [view_nodes(nodes)]
  })
}

fn view_nodes(nodes: Zipper(Node)) -> Element(message) {
  case nodes.count_visible_tasks(nodes) {
    0 -> view_empty()
    _count -> view_tree(zipper.tree(nodes), depth: 0)
  }
}

fn view_empty() -> Element(message) {
  html.div([attr.class("flex justify-center p-14 text-2xl text-zinc-400/50")], [
    html.div([], [html.text("Ingen oppgaver funnet")]),
  ])
}

fn view_tree(tree: Tree(Node), depth depth: Int) -> Element(message) {
  case tree.label(tree) {
    nodes.Root(count) ->
      html.section(
        [
          core.classes(case count < 5 {
            True -> flex_layout
            False -> grid_layout
          }),
        ],
        {
          use tree <- list.map(tree.children(tree))
          view_tree(tree, depth: 0)
        },
      )

    nodes.Category(Hidden, _name) -> element.none()
    nodes.Task(Hidden, _task) -> element.none()

    nodes.Category(Visible, name) ->
      view_category(name, depth, tree.children(tree))

    nodes.Task(Visible, task) -> view_task(task)
  }
}

fn view_category(
  name: String,
  depth: Int,
  children: List(Tree(Node)),
) -> Element(message) {
  let attrs = case depth {
    0 -> [
      core.classes([
        "inline-flex flex-col", "px-4 py-3 pb-1", "h-fit min-w-[150px]",
        "bg-white", "rounded-sm", "shadow-lg", "leading-relaxed",
      ]),
    ]

    _depth -> [attr.class("flex flex-col")]
  }

  html.div(attrs, [
    category_header(name, depth),
    element.fragment(list.map(children, view_tree(_, depth: depth + 1))),
  ])
}

fn category_header(name: String, depth: Int) -> Element(message) {
  let attrs = case depth {
    0 -> [attr.class("text-2xl font-semibold mb-2")]
    1 -> [attr.class("text-xl font-semibold mb-2")]
    _depth -> [attr.class("text font-semibold italic")]
  }

  html.header(attrs, [html.text(name)])
}

fn view_task(task: Task) -> Element(message) {
  let task_name =
    html.span(
      [
        core.classes([
          "flex font-medium text-sky-900",
          "underline group-hover:no-underline",
        ]),
      ],
      [html.text(task.name)],
    )

  let task_summary = {
    use text <- option.map(task.summary)
    html.summary([attr.class("block text-slate-600 text-sm")], [html.text(text)])
  }

  html.a(
    [
      attr.href("/oppgave/" <> task.id),
      core.classes([
        "flex flex-col", "group", "min-w-[150px]", "py-2 last-of-type:mb-2",
        "bg-pink-500/0",
      ]),
    ],
    [task_name, option.unwrap(task_summary, element.none())],
  )
}
