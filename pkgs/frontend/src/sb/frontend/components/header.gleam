import gleam/list
import lustre/attribute.{type Attribute} as attr
import lustre/element.{type Element}
import lustre/element/html
import sb/frontend/components/core
import sb/frontend/portals

pub fn view() -> Element(message) {
  html.header(
    [
      core.classes([
        "sticky top-0 z-(--z-header) h-(--header-height)",
        "flex justify-center items-stretch px-4",
        "select-none whitespace-nowrap font-medium",
        "shadow-md bg-gradient-to-t",
        "bg-white text-zinc-900 shadow-zinc-950/20",
      ]),
    ],
    [
      html.div(
        [
          attr.class(
            "flex items-stretch w-full select-none max-w-[var(--menu-width)]",
          ),
        ],
        [
          portals.links(),
          core.filler(),
          portals.actions(),
        ],
      ),
    ],
  )
}

fn link(
  attrs: List(Attribute(message)),
  content: List(Element(message)),
) -> Element(message) {
  html.a(
    list.append(
      [attr.class("group flex items-center px-1 whitespace-nowrap")],
      attrs,
    ),
    content,
  )
}

pub fn active_menu(text: String, href: String) -> Element(message) {
  link([attr.href(href)], [
    core.label(
      [attr.class("rounded-sm bg-cyan-700 text-neutral-50 text-shadow-25")],
      [html.text(text)],
    ),
  ])
}

pub fn inactive_menu(text: String, href: String) -> Element(message) {
  link([attr.href(href)], [
    core.label([attr.class("rounded-sm underline group-hover:no-underline")], [
      html.text(text),
    ]),
  ])
}
