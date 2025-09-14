import gleam/list
import lustre/attribute.{type Attribute, attribute} as attr
import lustre/element.{type Element}
import lustre/element/svg.{svg}

pub fn spinner_circle(attrs) {
  svg(
    list.append(attrs, [
      attribute("xmlns", "http://www.w3.org/2000/svg"),
      attribute("fill", "none"),
      attribute("viewBox", "0 0 24 24"),
      attr.class("h-5 w-5"),
    ]),
    [
      svg.circle([
        attr.class("opacity-25"),
        attribute("cx", "12"),
        attribute("cy", "12"),
        attribute("r", "10"),
        attribute("stroke", "currentColor"),
        attribute("stroke-width", "4"),
      ]),
      svg.path([
        attr.class("opacity-75"),
        attribute("fill", "currentColor"),
        attribute(
          "d",
          "M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z",
        ),
      ]),
    ],
  )
}

// https://heroicons.com

fn solid_attrs(attrs: List(Attribute(message))) -> List(Attribute(message)) {
  list.append(attrs, [
    attribute("xmlns", "http://www.w3.org/2000/svg"),
    attribute("fill", "currentColor"),
    attribute("viewBox", "0 0 24 24"),
    attr.class("size-6"),
  ])
}

fn outline_attrs(attrs: List(Attribute(message))) -> List(Attribute(message)) {
  list.append(attrs, [
    attribute("xmlns", "http://www.w3.org/2000/svg"),
    attribute("fill", "none"),
    attribute("viewBox", "0 0 24 24"),
    attribute("stroke-width", "1.5"),
    attribute("stroke", "currentColor"),
    attr.class("size-6"),
  ])
}

pub fn chevron_double_up_outline(
  attrs: List(Attribute(message)),
) -> Element(message) {
  svg(outline_attrs(attrs), [
    svg.path([
      attribute("stroke-linecap", "round"),
      attribute("stroke-linejoin", "round"),
      attribute("d", "m4.5 18.75 7.5-7.5 7.5 7.5"),
    ]),
    svg.path([
      attribute("stroke-linecap", "round"),
      attribute("stroke-linejoin", "round"),
      attribute("d", "m4.5 12.75 7.5-7.5 7.5 7.5"),
    ]),
  ])
}

pub fn forward_outline(attrs: List(Attribute(message))) -> Element(message) {
  svg(outline_attrs(attrs), [
    svg.path([
      attribute("stroke-linecap", "round"),
      attribute("stroke-linejoin", "round"),
      attribute(
        "d",
        "M3 8.689c0-.864.933-1.406 1.683-.977l7.108 4.061a1.125 1.125 0 0 1 0 1.954l-7.108 4.061A1.125 1.125 0 0 1 3 16.811V8.69ZM12.75 8.689c0-.864.933-1.406 1.683-.977l7.108 4.061a1.125 1.125 0 0 1 0 1.954l-7.108 4.061a1.125 1.125 0 0 1-1.683-.977V8.69Z",
      ),
    ]),
  ])
}

pub fn arrow_path_outline(attrs: List(Attribute(message))) -> Element(message) {
  svg(outline_attrs(attrs), [
    svg.path([
      attribute("stroke-linecap", "round"),
      attribute("stroke-linejoin", "round"),
      attribute(
        "d",
        "M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0 3.181 3.183a8.25 8.25 0 0 0 13.803-3.7M4.031 9.865a8.25 8.25 0 0 1 13.803-3.7l3.181 3.182m0-4.991v4.99",
      ),
    ]),
  ])
}

pub fn play_outline(attrs: List(Attribute(message))) -> Element(message) {
  svg(outline_attrs(attrs), [
    svg.path([
      attribute("stroke-linecap", "round"),
      attribute("stroke-linejoin", "round"),
      attribute(
        "d",
        "M5.25 5.653c0-.856.917-1.398 1.667-.986l11.54 6.347a1.125 1.125 0 0 1 0 1.972l-11.54 6.347a1.125 1.125 0 0 1-1.667-.986V5.653Z",
      ),
    ]),
  ])
}

pub fn play_pause_outline(attrs: List(Attribute(message))) -> Element(message) {
  svg(outline_attrs(attrs), [
    svg.path([
      attribute("stroke-linecap", "round"),
      attribute("stroke-linejoin", "round"),
      attribute(
        "d",
        "M21 7.5V18M15 7.5V18M3 16.811V8.69c0-.864.933-1.406 1.683-.977l7.108 4.061a1.125 1.125 0 0 1 0 1.954l-7.108 4.061A1.125 1.125 0 0 1 3 16.811Z",
      ),
    ]),
  ])
}

pub fn bolt_solid(attrs: List(Attribute(message))) -> Element(message) {
  svg(solid_attrs(attrs), [
    svg.path([
      attribute("fill-rule", "evenodd"),
      attribute(
        "d",
        "M14.615 1.595a.75.75 0 0 1 .359.852L12.982 9.75h7.268a.75.75 0 0 1 .548 1.262l-10.5 11.25a.75.75 0 0 1-1.272-.71l1.992-7.302H3.75a.75.75 0 0 1-.548-1.262l10.5-11.25a.75.75 0 0 1 .913-.143Z",
      ),
    ]),
  ])
}

pub fn bolt_outline(attrs: List(Attribute(message))) -> Element(message) {
  svg(outline_attrs(attrs), [
    svg.path([
      attribute("stroke-linecap", "round"),
      attribute("stroke-linejoin", "round"),
      attribute(
        "d",
        "m3.75 13.5 10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75Z",
      ),
    ]),
  ])
}

pub fn document_plus_outline(
  attrs: List(Attribute(message)),
) -> Element(message) {
  svg(outline_attrs(attrs), [
    svg.path([
      attribute("stroke-linecap", "round"),
      attribute("stroke-linejoin", "round"),
      attribute(
        "d",
        "M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m3.75 9v6m3-3H9m1.5-12H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z",
      ),
    ]),
  ])
}

pub fn exclamation_circle_solid(
  attrs: List(Attribute(message)),
) -> Element(message) {
  svg(solid_attrs(attrs), [
    svg.path([
      attribute("fill-rule", "evenodd"),
      attribute(
        "d",
        "M2.25 12c0-5.385 4.365-9.75 9.75-9.75s9.75 4.365 9.75 9.75-4.365 9.75-9.75 9.75S2.25 17.385 2.25 12ZM12 8.25a.75.75 0 0 1 .75.75v3.75a.75.75 0 0 1-1.5 0V9a.75.75 0 0 1 .75-.75Zm0 8.25a.75.75 0 1 0 0-1.5.75.75 0 0 0 0 1.5Z",
      ),
    ]),
  ])
}

pub fn exclamation_circle_outline(
  attrs: List(Attribute(message)),
) -> Element(message) {
  svg(outline_attrs(attrs), [
    svg.path([
      attribute("stroke-linecap", "round"),
      attribute("stroke-linejoin", "round"),
      attribute(
        "d",
        "M12 9v3.75m9-.75a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9 3.75h.008v.008H12v-.008Z",
      ),
    ]),
  ])
}

pub fn exclamation_triangle_outline(
  attrs: List(Attribute(message)),
) -> Element(message) {
  svg(outline_attrs(attrs), [
    svg.path([
      attribute("stroke-linecap", "round"),
      attribute("stroke-linejoin", "round"),
      attribute(
        "d",
        "M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z",
      ),
    ]),
  ])
}

pub fn magnifying_glass_outline(
  attrs: List(Attribute(message)),
) -> Element(message) {
  svg(outline_attrs(attrs), [
    svg.path([
      attribute("stroke-linecap", "round"),
      attribute("stroke-linejoin", "round"),
      attribute(
        "d",
        "M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z",
      ),
    ]),
  ])
}

pub fn x_mark_outline(attrs: List(Attribute(message))) -> Element(message) {
  svg(outline_attrs(attrs), [
    svg.path([
      attribute("stroke-linecap", "round"),
      attribute("stroke-linejoin", "round"),
      attribute("d", "M6 18L18 6M6 6l12 12"),
    ]),
  ])
}

pub fn eye_outline(attrs: List(Attribute(message))) -> Element(message) {
  svg(outline_attrs(attrs), [
    svg.path([
      attribute("stroke-linecap", "round"),
      attribute("stroke-linejoin", "round"),
      attribute(
        "d",
        "M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z",
      ),
    ]),
    svg.path([
      attribute("stroke-linecap", "round"),
      attribute("stroke-linejoin", "round"),
      attribute("d", "M15 12a3 3 0 11-6 0 3 3 0 016 0z"),
    ]),
  ])
}

pub fn eye_slash_outline(attr: List(Attribute(message))) -> Element(message) {
  svg(outline_attrs(attr), [
    svg.path([
      attribute("stroke-linecap", "round"),
      attribute("stroke-linejoin", "round"),
      attribute(
        "d",
        "M3.98 8.223A10.477 10.477 0 001.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.45 10.45 0 0112 4.5c4.756 0 8.773 3.162 10.065 7.498a10.523 10.523 0 01-4.293 5.774M6.228 6.228L3 3m3.228 3.228l3.65 3.65m7.894 7.894L21 21m-3.228-3.228l-3.65-3.65m0 0a3 3 0 10-4.243-4.243m4.242 4.242L9.88 9.88",
      ),
    ]),
  ])
}

pub fn window_outline(attrs: List(Attribute(message))) -> Element(message) {
  svg(outline_attrs(attrs), [
    svg.path([
      attribute("stroke-linecap", "round"),
      attribute("stroke-linejoin", "round"),
      attribute(
        "d",
        "M3 8.25V18a2.25 2.25 0 002.25 2.25h13.5A2.25 2.25 0 0021 18V8.25m-18 0V6a2.25 2.25 0 012.25-2.25h13.5A2.25 2.25 0 0121 6v2.25m-18 0h18M5.25 6h.008v.008H5.25V6zM7.5 6h.008v.008H7.5V6zm2.25 0h.008v.008H9.75V6z",
      ),
    ]),
  ])
}

pub fn play_circle_outline(attrs: List(Attribute(message))) -> Element(message) {
  svg(outline_attrs(attrs), [
    svg.path([
      attribute("stroke-linecap", "round"),
      attribute("stroke-linejoin", "round"),
      attribute("d", "M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"),
    ]),
    svg.path([
      attribute("stroke-linecap", "round"),
      attribute("stroke-linejoin", "round"),
      attribute(
        "d",
        "M15.91 11.672a.375.375 0 0 1 0 .656l-5.603 3.113a.375.375 0 0 1-.557-.328V8.887c0-.286.307-.466.557-.327l5.603 3.112Z",
      ),
    ]),
  ])
}

pub fn pause_outline(attrs: List(Attribute(message))) -> Element(message) {
  svg(outline_attrs(attrs), [
    svg.path([
      attribute("stroke-linecap", "round"),
      attribute("stroke-linejoin", "round"),
      attribute("d", "M15.75 5.25v13.5m-7.5-13.5v13.5"),
    ]),
  ])
}

pub fn check_outline(attrs: List(Attribute(message))) -> Element(message) {
  svg(outline_attrs(attrs), [
    svg.path([
      attribute("stroke-linecap", "round"),
      attribute("stroke-linejoin", "round"),
      attribute("d", "m4.5 12.75 6 6 9-13.5"),
    ]),
  ])
}

pub fn user_outline(attrs: List(Attribute(message))) -> Element(message) {
  svg(outline_attrs(attrs), [
    svg.path([
      attribute("stroke-linecap", "round"),
      attribute("stroke-linejoin", "round"),
      attribute(
        "d",
        "M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z",
      ),
    ]),
  ])
}

pub fn chevron_right_outline(
  attrs: List(Attribute(message)),
) -> Element(message) {
  svg(outline_attrs(attrs), [
    svg.path([
      attribute("stroke-linecap", "round"),
      attribute("stroke-linejoin", "round"),
      attribute("d", "m8.25 4.5 7.5 7.5-7.5 7.5"),
    ]),
  ])
}

pub fn chevron_down_outline(attrs: List(Attribute(message))) -> Element(message) {
  svg(outline_attrs(attrs), [
    svg.path([
      attribute("stroke-linecap", "round"),
      attribute("stroke-linejoin", "round"),
      attribute("d", "m19.5 8.25-7.5 7.5-7.5-7.5"),
    ]),
  ])
}

pub fn clock_outline(attrs: List(Attribute(message))) -> Element(message) {
  svg(outline_attrs(attrs), [
    svg.path([
      attribute("stroke-linecap", "round"),
      attribute("stroke-linejoin", "round"),
      attribute("d", "M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"),
    ]),
  ])
}

pub fn squares22(attrs: List(Attribute(message))) -> Element(message) {
  svg(outline_attrs(attrs), [
    svg.path([
      attribute("stroke-linecap", "round"),
      attribute("stroke-linejoin", "round"),
      attribute(
        "d",
        "M3.75 6A2.25 2.25 0 0 1 6 3.75h2.25A2.25 2.25 0 0 1 10.5 6v2.25a2.25 2.25 0 0 1-2.25 2.25H6a2.25 2.25 0 0 1-2.25-2.25V6ZM3.75 15.75A2.25 2.25 0 0 1 6 13.5h2.25a2.25 2.25 0 0 1 2.25 2.25V18a2.25 2.25 0 0 1-2.25 2.25H6A2.25 2.25 0 0 1 3.75 18v-2.25ZM13.5 6a2.25 2.25 0 0 1 2.25-2.25H18A2.25 2.25 0 0 1 20.25 6v2.25A2.25 2.25 0 0 1 18 10.5h-2.25a2.25 2.25 0 0 1-2.25-2.25V6ZM13.5 15.75a2.25 2.25 0 0 1 2.25-2.25H18a2.25 2.25 0 0 1 2.25 2.25V18A2.25 2.25 0 0 1 18 20.25h-2.25A2.25 2.25 0 0 1 13.5 18v-2.25Z",
      ),
    ]),
  ])
}

pub fn queue_list_outline(attrs: List(Attribute(message))) -> Element(message) {
  svg(outline_attrs(attrs), [
    svg.path([
      attribute("stroke-linecap", "round"),
      attribute("stroke-linejoin", "round"),
      attribute(
        "d",
        "M3.75 12h16.5m-16.5 3.75h16.5M3.75 19.5h16.5M5.625 4.5h12.75a1.875 1.875 0 0 1 0 3.75H5.625a1.875 1.875 0 0 1 0-3.75Z",
      ),
    ]),
  ])
}
