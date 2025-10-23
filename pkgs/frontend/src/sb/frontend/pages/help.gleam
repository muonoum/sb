import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import sb/frontend/components/header
import sb/frontend/components/search
import sb/frontend/components/sheet
import sb/frontend/components/sidebar
import sb/frontend/portals

pub opaque type Model {
  Model(search: String)
}

pub opaque type Message {
  Search(String)
}

pub fn init() -> #(Model, Effect(Message)) {
  #(Model(search: ""), effect.none())
}

pub fn update(model: Model, _message: Message) -> #(Model, Effect(Message)) {
  #(model, effect.none())
}

pub fn view(model: Model) -> Element(Message) {
  element.fragment([page_header(model), page(model)])
}

fn page_header(model: Model) -> Element(Message) {
  element.fragment([
    portals.into_menu([
      header.inactive_menu("Oppgaver", "/oppgaver"),
      header.inactive_menu("Jobber", "/jobber"),
      header.active_menu("Hjelp", "/hjelp"),
    ]),
    portals.into_actions([
      search.view(search: model.search, clear: Search(""), attributes: [
        attr.class("rounded-md"),
        attr.placeholder("Søk"),
        event.on_input(Search),
      ]),
    ]),
  ])
}

fn page(_model: Model) -> Element(Message) {
  sheet.view([], header: [], padding: [], body: [
    html.div([attr.class("flex rounded-t-md grow")], [
      html.div([attr.class("flex flex-col basis-4/6")], []),
      sidebar(),
    ]),
  ])
}

fn sidebar() -> Element(Message) {
  sidebar.view([])
}
