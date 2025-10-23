import lustre/attribute as attr
import lustre/element.{type Element}
import lustre/element/html

pub fn view(content: List(Element(message))) -> Element(message) {
  html.div(
    [attr.class("rounded-tr-md grow border-s border-stone-300 bg-stone-100/50")],
    [
      html.div([attr.class("sticky top-0")], [
        html.div([attr.class("relative flex flex-col grow p-4")], content),
      ]),
    ],
  )
}
