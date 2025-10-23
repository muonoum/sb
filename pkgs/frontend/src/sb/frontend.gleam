import gleam/string
import gleam/uri
import lustre
import lustre/attribute as attr
import lustre/element.{type Element}
import lustre/element/html
import plinth/browser/window
import sb/frontend/app

pub fn main() {
  let app = app.new()
  let assert Ok(uri) = uri.parse(window.location()) as "window location"

  case lustre.start(app, "body", uri) {
    Error(error) -> panic as string.inspect(error)
    Ok(_app) -> Nil
  }
}

pub fn page() -> Element(a) {
  html.html([], [
    html.head([], [
      html.title([], "sb"),
      html.meta([attr.charset("utf-8")]),
      html.meta([
        attr.name("viewport"),
        attr.content("width=device-width,initial-scale=1"),
      ]),
      html.script(
        [
          attr.type_("module"),
          attr.src("/lustre/lustre-server-component.mjs"),
        ],
        "",
      ),
      html.script(
        [attr.type_("module"), attr.src("/lustre/lustre-portal.mjs")],
        "",
      ),
      html.link([attr.rel("stylesheet"), attr.href("/app.css")]),
      html.script([attr.type_("module"), attr.src("/app.js")], ""),
    ]),
    html.body([attr.class("bg-zinc-700 text-zinc-800 overscroll-y-none")], [
      html.div([attr.class("flex justify-center items-center h-screen")], [
        html.div([attr.class("p-4 bg-white rounded")], [
          element.text("•••"),
        ]),
      ]),
    ]),
  ])
}
