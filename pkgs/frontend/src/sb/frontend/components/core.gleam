import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/string
import lustre/attribute.{type Attribute} as attr
import lustre/element.{type Element}
import lustre/element/html
import sb/forms/value.{type Value}
import sb/frontend/components/icons

pub fn maybe(
  value: Option(v),
  to_element: fn(v) -> Element(message),
) -> Element(message) {
  option.map(value, to_element)
  |> option.lazy_unwrap(element.none)
}

pub fn classes(names: List(String)) -> Attribute(message) {
  attr.class(string.join(names, " "))
}

pub fn filler() -> Element(message) {
  html.div([attr.class("grow")], [])
}

pub fn inspect(attr: List(Attribute(message)), value) -> Element(message) {
  let attr = list.append(attr, [attr.class("font-semibold font-mono")])
  html.div(attr, [html.text(string.inspect(value))])
}

pub fn inline_value(value: Value) -> Element(message) {
  // TODO

  case value {
    value.String(string) -> html.text(string)
    value.Int(..) | value.Float(..) | value.Bool(..) | value.Null ->
      html.text(json.to_string(value.to_json(value)))

    value ->
      html.span([attr.class("font-semibold font-mono")], [
        html.text(json.to_string(value.to_json(value))),
      ])
  }
}

pub fn spinner(
  attrs: List(Attribute(message)),
  visible: Bool,
) -> Element(message) {
  html.div(
    list.append(attrs, [
      classes([
        "self-center",
        "transition-visibility",
        case visible {
          False -> "invisible opacity-0"
          True -> "visible opacity-100"
        },
      ]),
    ]),
    [icons.spinner_circle([attr.class("animate-spin ms-1")])],
  )
}

pub fn page(content: List(Element(message))) -> Element(message) {
  html.div(
    [
      attr.id("sb/page"),
      attr.class(
        "fixed inset-0 top-(--header-height) overflow-y-auto scroll-smooth",
      ),
    ],
    content,
  )
}

pub fn label(
  attrs: List(Attribute(message)),
  content: List(Element(message)),
) -> Element(message) {
  list.append([attr.class("flex items-center gap-1 px-2.5 py-1.5")], attrs)
  |> html.span(content)
}

pub fn button(
  button attrs: List(Attribute(message)),
  label label_attrs: List(Attribute(message)),
  body content: List(Element(message)),
) -> Element(message) {
  let attrs =
    list.append(attrs, [
      attr.class("flex items-center px-1 enabled:cursor-pointer"),
      attr.class("group whitespace-nowrap"),
    ])

  let label_attrs =
    list.append(label_attrs, [
      attr.class("rounded-sm font-medium pointer-events-none"),
      attr.class("underline group-hover:no-underline"),
    ])

  html.button(attrs, [label(label_attrs, content)])
}
