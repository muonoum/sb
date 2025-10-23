import lustre/attribute as attr
import lustre/element.{type Element}
import lustre/element/html
import lustre/portal

const menu_target = "sb-links"

const actions_target = "sb-actions"

pub fn menu() {
  html.div([attr.id(menu_target), attr.class("contents")], [])
}

pub fn actions() {
  html.div([attr.id(actions_target), attr.class("contents")], [])
}

pub fn into_menu(elements: List(Element(message))) {
  portal.to("#" <> menu_target, [], elements)
}

pub fn into_actions(elements: List(Element(message))) {
  portal.to("#" <> actions_target, [], elements)
}
