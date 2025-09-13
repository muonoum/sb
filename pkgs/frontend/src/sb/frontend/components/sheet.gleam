import gleam/list
import lustre/attribute.{type Attribute} as attr
import lustre/element.{type Element}
import lustre/element/html

import sb/frontend/components/core

pub fn view(
  attrs: List(Attribute(message)),
  header header: List(Element(message)),
  body body: List(Element(message)),
  padding padding: List(Element(message)),
) -> Element(message) {
  element.fragment([
    case padding {
      [] -> element.none()

      padding ->
        html.div(
          [
            core.classes([
              "fixed flex top-2/4 left-1/2 -translate-x-2/4 z-0",
              "w-(--sheet-width) min-w-[850px] h-screen",
            ]),
          ],
          padding,
        )
    },
    html.div(
      list.append(attrs, [
        core.classes([
          "relative flex flex-col max-w-(--sheet-width) min-w-[850px] z-(--z-sheet)",
          "min-h-[calc(100vh-var(--header-height)-var(--page-margin))]",
          "mt-(--page-margin) mx-auto shadow",
          "rounded-t-sm shadow-xl bg-white text-stone-800",
        ]),
      ]),
      [
        case header {
          [] -> element.none()
          content -> view_header(content)
        },
        ..body
      ],
    ),
  ])
}

fn view_header(body: List(Element(message))) -> Element(message) {
  html.div(
    [
      core.classes([
        "flex items-stretch justify-between", "whitespace-nowrap",
        "font-semibold", "rounded-t-sm h-(--header-height)",
        "bg-gradient-to-b from-zinc-200 to-zinc-300 text-zinc-800",
      ]),
    ],
    [
      html.div(
        [attr.class("flex items-stretch grow px-4 py-2 rounded-tl-sm")],
        body,
      ),
    ],
  )
}
