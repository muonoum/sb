import gleam/bool
import gleam/dynamic/decode.{type Decoder}
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import gleam/uri.{type Uri}
import lustre/attribute.{type Attribute, attribute} as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import lustre/server_component as server
import modem
import sb/extra/function
import sb/extra/uri as uri_extra
import sb/extra_client
import sb/frontend/components/core
import sb/frontend/components/header
import sb/frontend/components/search
import sb/frontend/components/sheet
import sb/frontend/components/sidebar
import sb/frontend/portal

const search_debounce = 250

pub opaque type Model {
  Model(filter: Filter, search: String, debounce: Int)
}

pub type Filter {
  Filter(
    requested: Bool,
    started: Bool,
    failed: Bool,
    succeeded: Bool,
    search: String,
    ownership: Ownership,
  )
}

pub type State {
  Requested
  Started
  Finished
}

pub type Ownership {
  AllJobs
  MyApprovals
  MyJobs
}

pub type Message {
  ScrollToTop
  ScrollTo(State)
  SetFilter(Filter)
  Search(String)
  ApplySearch(String, debounce: Int)
}

pub fn init(uri: Uri) -> #(Model, Effect(Message)) {
  let search = uri_extra.optional_query(uri, "search")

  let filter =
    Filter(
      requested: True,
      started: True,
      succeeded: True,
      failed: True,
      ownership: AllJobs,
      search:,
    )

  #(Model(filter:, search:, debounce: 0), effect.none())
}

pub fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  case message {
    ScrollTo(state) -> #(model, scroll_to_state(state))
    ScrollToTop -> #(model, scroll_to_top())
    SetFilter(filter) -> #(Model(..model, filter:), effect.none())

    Search("") -> {
      let filter = Filter(..model.filter, search: "")
      let effect = modem.replace("/jobber", None, None)
      #(Model(filter:, search: "", debounce: 0), effect)
    }

    Search(search) -> {
      let debounce = model.debounce + 1
      let effect =
        extra_client.schedule(search_debounce, ApplySearch(search, debounce))
      #(Model(..model, debounce:, search:), effect)
    }

    ApplySearch(search, debounce:) if debounce == model.debounce -> {
      let trimmed_search = string.trim(search)

      let query = {
        let search = uri.percent_encode(trimmed_search)
        use <- bool.guard(search == "", None)
        Some("search=" <> search)
      }

      let filter = Filter(..model.filter, search: trimmed_search)
      let effect = modem.replace("/jobber", query, None)
      #(Model(..model, search:, filter:), effect)
    }

    ApplySearch(_search, debounce: _) -> #(model, effect.none())
  }
}

fn scroll_to_top() -> Effect(Message) {
  use _dispatch <- effect.from()
  use <- function.return(result.unwrap(_, Nil))
  use element <- result.map(extra_client.get_element("sb-page"))
  extra_client.scroll_to_top(element)
}

fn scroll_to_state(state: State) -> Effect(Message) {
  use _dispatch <- effect.from()
  use <- function.return(result.unwrap(_, Nil))
  use element <- result.map(extra_client.get_element(get_state_id(state)))
  extra_client.scroll_into_view(element)
}

fn get_state_id(state: State) -> String {
  case state {
    Requested -> "sb-requested-jobs"
    Started -> "sb-started-jobs"
    Finished -> "sb-finished-jobs"
  }
}

fn checked(condition: Bool) -> Attribute(message) {
  use <- bool.lazy_guard(!condition, attr.none)
  attr.attribute("checked", "true")
}

fn set_ownership(filter: Filter, ownership: Ownership) -> Decoder(Message) {
  decode.success(SetFilter(Filter(..filter, ownership:)))
}

fn set_requested_jobs(filter: Filter) -> Decoder(Message) {
  use requested <- decode.then(decode.at(["target", "checked"], decode.bool))
  decode.success(SetFilter(Filter(..filter, requested:)))
}

fn set_started_jobs(filter: Filter) -> Decoder(Message) {
  use started <- decode.then(decode.at(["target", "checked"], decode.bool))
  decode.success(SetFilter(Filter(..filter, started:)))
}

fn set_failed_jobs(filter: Filter) -> Decoder(Message) {
  use failed <- decode.then(decode.at(["target", "checked"], decode.bool))
  decode.success(SetFilter(Filter(..filter, failed:)))
}

fn set_successful_jobs(filter: Filter) -> Decoder(Message) {
  use succeeded <- decode.then(decode.at(["target", "checked"], decode.bool))
  decode.success(SetFilter(Filter(..filter, succeeded:)))
}

pub fn view(model: Model) -> Element(Message) {
  element.fragment([
    portal.into_menu([
      header.inactive_menu("Oppgaver", "/oppgaver"),
      header.active_menu("Jobber", "/jobber"),
      header.inactive_menu("Hjelp", "/hjelp"),
    ]),
    portal.into_actions([
      search.view(search: model.search, clear: Search(""), attributes: [
        attr.class("rounded-md"),
        attr.placeholder("Finn jobb"),
        event.on_input(Search),
      ]),
    ]),
    core.page([
      sheet.view([], header: [], body: [body(model)], padding: [
        padding(),
      ]),
    ]),
  ])
}

fn padding() -> Element(Message) {
  html.div([attr.class("bg-white flex grow")], [
    html.div([attr.class("basis-4/6")], []),
    html.div(
      [attr.class("basis-2/6 border-s border-stone-300 bg-stone-100/50")],
      [],
    ),
  ])
}

fn body(model: Model) -> Element(Message) {
  html.div([attr.class("flex rounded-t-md grow")], [
    view_jobs(model),
    view_sidebar(model.filter),
  ])
}

fn view_jobs(model: Model) -> Element(Message) {
  let Model(filter:, ..) = model

  let ownership = case filter.ownership {
    AllJobs -> "all-jobs"
    MyApprovals -> "my-approvals"
    MyJobs -> "my-jobs"
  }

  html.div([attr.class("flex flex-col basis-4/6")], [
    started_jobs(filter, ownership),
    requested_jobs(filter, ownership),
    finished_jobs(filter, ownership),
  ])
}

fn started_jobs(filter: Filter, ownership: String) -> Element(message) {
  server.element(
    [
      attr.id("sb-started-jobs"),
      server.route("/components/jobs/started"),
      attribute("data-search", filter.search),
      attribute("data-ownership", ownership),
      attribute("data-status", {
        case filter.started {
          True -> "all"
          False -> "none"
        }
      }),
    ],
    [],
  )
}

fn requested_jobs(filter: Filter, ownership: String) -> Element(message) {
  server.element(
    [
      attr.id("sb-requested-jobs"),
      server.route("/components/jobs/requested"),
      attribute("data-search", filter.search),
      attribute("data-ownership", ownership),
      attribute("data-status", {
        case filter.requested {
          True -> "all"
          False -> "none"
        }
      }),
    ],
    [],
  )
}

fn finished_jobs(filter: Filter, ownership: String) -> Element(message) {
  server.element(
    [
      attr.id("sb-finished-jobs"),
      server.route("/components/jobs/finished"),
      attribute("data-search", filter.search),
      attribute("data-ownership", ownership),
      attribute("data-status", {
        case filter.succeeded, filter.failed {
          True, True -> "all"
          False, False -> "none"
          True, False -> "succeeded"
          False, True -> "failed"
        }
      }),
    ],
    [],
  )
}

fn view_sidebar(filter: Filter) -> Element(Message) {
  sidebar.view([
    sidebar_header(),
    state_selector(),
    ownership_selector(filter),
    active_state_selector(filter),
    finished_state_selector(filter),
  ])
}

fn sidebar_header() -> Element(message) {
  html.div([core.classes(["flex items-start justify-between mb-4"])], [
    html.h1([attr.class("text-xl font-semibold")], [html.text("Jobber")]),
  ])
}

fn state_selector() -> Element(Message) {
  html.div([attr.class("flex flex gap-4 mb-8")], [
    select_state(Started, top: True),
    select_state(Requested, top: False),
    select_state(Finished, top: False),
  ])
}

fn select_state(state: State, top scroll_to_top: Bool) -> Element(Message) {
  html.a(
    [
      attr.class("cursor-pointer select-none hover:underline"),
      event.on_click(case scroll_to_top {
        True -> ScrollToTop
        False -> ScrollTo(state)
      }),
    ],
    [
      html.text(case state {
        Requested -> "Til godkjenning"
        Started -> "Aktive"
        Finished -> "Fullførte"
      }),
    ],
  )
}

fn ownership_selector(filter: Filter) -> Element(Message) {
  html.div([attr.class("flex flex-col gap-1 mb-4")], [
    html.h2([attr.class("font-semibold mb-2")], [html.text("Vis")]),
    select_all_jobs(filter),
    select_my_approvals(filter),
    select_my_jobs(filter),
  ])
}

fn select_all_jobs(filter: Filter) -> Element(Message) {
  html.div([attr.class("flex gap-2 items-center")], [
    html.input([
      attr.class("accent-cyan-800"),
      attr.type_("radio"),
      attr.name("ownership"),
      attr.id("all-jobs"),
      checked(filter.ownership == AllJobs),
      event.on("change", set_ownership(filter, AllJobs)),
    ]),
    html.label([attr.class("select-none"), attr.for("all-jobs")], [
      html.text("Alle jobber"),
    ]),
  ])
}

fn select_my_approvals(filter: Filter) -> Element(Message) {
  html.div([attr.class("flex gap-2 items-center")], [
    html.input([
      attr.class("accent-cyan-800"),
      attr.type_("radio"),
      attr.name("ownership"),
      attr.id("my-approvals"),
      checked(filter.ownership == MyApprovals),
      event.on("change", set_ownership(filter, MyApprovals)),
    ]),
    html.label([attr.class("select-none"), attr.for("my-approvals")], [
      html.text("Mine godkjenninger"),
    ]),
  ])
}

fn select_my_jobs(filter: Filter) -> Element(Message) {
  html.div([attr.class("flex gap-2 items-center")], [
    html.input([
      attr.class("accent-cyan-800"),
      attr.type_("radio"),
      attr.name("ownership"),
      attr.id("my-jobs"),
      checked(filter.ownership == MyJobs),
      event.on("change", set_ownership(filter, MyJobs)),
    ]),
    html.label([attr.class("select-none"), attr.for("my-jobs")], [
      html.text("Mine jobber"),
    ]),
  ])
}

fn active_state_selector(filter: Filter) -> Element(Message) {
  html.div([attr.class("flex flex-col gap-1 mb-8")], [
    select_started_jobs(filter),
    select_requested_jobs(filter),
  ])
}

fn select_started_jobs(filter: Filter) -> Element(Message) {
  html.div([attr.class("flex gap-2 items-center")], [
    html.input([
      attr.class("accent-cyan-800"),
      attr.type_("checkbox"),
      attr.id("started-jobs"),
      checked(filter.started),
      server.include(event.on("change", set_started_jobs(filter)), [
        "target.checked",
      ]),
    ]),
    html.label([attr.class("select-none"), attr.for("started-jobs")], [
      html.text("Aktive jobber"),
    ]),
  ])
}

fn select_requested_jobs(filter: Filter) -> Element(Message) {
  html.div([attr.class("flex gap-2 items-center")], [
    html.input([
      attr.class("accent-cyan-800"),
      attr.type_("checkbox"),
      attr.id("requested-jobs"),
      checked(filter.requested),
      server.include(event.on("change", set_requested_jobs(filter)), [
        "target.checked",
      ]),
    ]),
    html.label([attr.class("select-none"), attr.for("requested-jobs")], [
      html.text("Jobber til godkjenning"),
    ]),
  ])
}

fn finished_state_selector(filter: Filter) -> Element(Message) {
  html.div([attr.class("flex flex-col gap-1 mb-4")], [
    html.h2([attr.class("font-semibold mb-2")], [html.text("Fullførte jobber")]),
    select_failed_jobs(filter),
    select_successful_jobs(filter),
  ])
}

fn select_failed_jobs(filter: Filter) -> Element(Message) {
  html.div([attr.class("flex gap-2 items-center")], [
    html.input([
      attr.class("accent-cyan-800"),
      attr.type_("checkbox"),
      attr.id("failed-jobs"),
      checked(filter.failed),
      server.include(event.on("change", set_failed_jobs(filter)), [
        "target.checked",
      ]),
    ]),
    html.label([attr.class("select-none"), attr.for("failed-jobs")], [
      html.text("Jobber med feil"),
    ]),
  ])
}

fn select_successful_jobs(filter: Filter) -> Element(Message) {
  html.div([attr.class("flex gap-2 items-center")], [
    html.input([
      attr.class("accent-cyan-800"),
      attr.type_("checkbox"),
      attr.id("successful-jobs"),
      checked(filter.succeeded),
      server.include(event.on("change", set_successful_jobs(filter)), [
        "target.checked",
      ]),
    ]),
    html.label([attr.class("select-none"), attr.for("successful-jobs")], [
      html.text("Vellykkede jobber"),
    ]),
  ])
}
