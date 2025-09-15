import gleam/option.{type Option, None, Some}
import lustre/attribute as attr
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import sb/frontend/components/core

const input_style = [
  "rounded-md border px-3 py-1.5 outline-transparent shadow-inner",
  "transition-[border-color,outline] duration-200",
  "bg-white border-stone-900/30 placeholder-zinc-500/80",
  "focus:outline focus:outline-4 focus:outline-offset-0",
  "focus:border-stone-950/60 focus:outline-stone-900/20",
]

pub type Config(message) {
  Config(id: String, placeholder: Option(String), input: fn(String) -> message)
}

pub fn text(value: String, config: Config(message)) -> Element(message) {
  html.input([
    attr.type_("text"),
    attr.value(value),
    core.classes(input_style),
    event.on_input(config.input),
    case config.placeholder {
      Some(string) -> attr.placeholder(string)
      None -> attr.none()
    },
  ])
}

pub fn textarea(value: String, config: Config(message)) -> Element(message) {
  let attr = [
    attr.value(value),
    attr.class("grow shadow-inner min-h-(--minimum-textarea-height)"),
    core.classes(input_style),
    event.on_input(config.input),
    case config.placeholder {
      Some(string) -> attr.placeholder(string)
      None -> attr.none()
    },
  ]

  html.textarea(attr, value)
}
