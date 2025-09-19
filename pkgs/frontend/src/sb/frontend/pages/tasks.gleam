import gleam/bool
import gleam/option.{None, Some}
import gleam/string
import gleam/uri.{type Uri}
import lustre/attribute.{attribute} as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/event
import lustre/server_component as server
import modem
import sb/extra
import sb/extra_client
import sb/frontend/components/header
import sb/frontend/components/search
import sb/frontend/portals

const search_debounce = 250

pub opaque type Model {
  Model(search: String, debounce: Int)
}

pub opaque type Message {
  Search(String)
  ApplySearch(String, debounce: Int)
}

pub fn init(uri: Uri) -> #(Model, Effect(Message)) {
  let search = extra.get_query(uri, "search")
  let model = Model(search:, debounce: 0)
  #(model, effect.none())
}

pub fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  case message {
    Search("") -> {
      let model = Model(search: "", debounce: 0)
      let effect = modem.replace("/oppgaver", None, None)
      #(model, effect)
    }

    Search(search) -> {
      let debounce = model.debounce + 1
      let model = Model(debounce:, search:)

      let effect =
        search_debounce
        |> extra_client.schedule(ApplySearch(search, debounce))

      #(model, effect)
    }

    ApplySearch(search, debounce:) if debounce == model.debounce -> {
      let query = {
        let search = uri.percent_encode(string.trim(search))
        use <- bool.guard(search == "", None)
        Some("search=" <> search)
      }

      #(model, modem.replace("/oppgaver", query, None))
    }

    ApplySearch(_search, debounce: _) -> #(model, effect.none())
  }
}

pub fn view(model: Model, uri: Uri) -> Element(Message) {
  element.fragment([
    portals.into_menu([
      header.active_menu("Oppgaver", "/oppgaver"),
      header.inactive_menu("Jobber", "/jobber"),
      header.inactive_menu("Hjelp", "/hjelp"),
      server.element(
        [attr.class("contents"), server.route("/components/errors")],
        [],
      ),
    ]),
    portals.into_actions([
      search.view(search: model.search, clear: Search(""), attributes: [
        attr.class("rounded-md"),
        attr.placeholder("Finn kategori eller oppgave"),
        event.on_input(Search),
      ]),
    ]),
    server.element(
      [
        server.route("/components/tasks"),
        attribute("search", extra.get_query(uri, "search")),
      ],
      [],
    ),
  ])
}
