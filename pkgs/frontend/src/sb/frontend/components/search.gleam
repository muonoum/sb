import gleam/list
import lustre/attribute.{type Attribute} as attr
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import sb/frontend/components/core
import sb/frontend/components/icons

pub fn view(
  search terms: String,
  clear clear: message,
  attributes attrs: List(Attribute(message)),
) -> Element(message) {
  let attrs =
    list.append(attrs, [
      attr.type_("text"),
      attr.value(terms),
      core.classes([
        "outline-transparent shadow-inner", "grow border px-3 my-[10px]",
        "transition-[border-color,outline] duration-200",
        "focus:outline focus:outline-4 focus:outline-offset-0",
        "bg-white/25 border-stone-900/30 placeholder-zinc-500",
        "focus:border-stone-950/60 focus:outline-stone-900/20",
      ]),
    ])

  html.div([attr.class("relative flex w-[450px] min-w-[200px] text-sm")], [
    html.input(attrs),
    icon([attr.class("right-[3px] top-1/2 -translate-y-2/4")], terms, clear),
  ])
}

pub fn icon(
  attrs: List(Attribute(message)),
  terms: String,
  clear: message,
) -> Element(message) {
  let attrs =
    list.append(attrs, [
      event.on_click(clear),
      attr.class("absolute rounded-r-sm py-[7px] px-[9px]"),
      attr.class(case terms {
        "" -> "pointer-events-none"
        _terms -> "cursor-pointer"
      }),
    ])

  html.div(attrs, [
    case terms {
      "" ->
        icons.magnifying_glass_outline([
          attr.class("stroke-sky-800 drop-shadow-xs"),
        ])

      _terms ->
        icons.x_mark_outline([
          attr.class("stroke-amber-700 drop-shadow-xs"),
          attr.class("pointer-events-none"),
        ])
    },
  ])
}
