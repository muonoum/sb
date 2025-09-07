import lustre/attribute as attr
import lustre/element.{type Element}
import lustre/element/html
import lustre/portal

pub const links_target = "sb-links"

pub const actions_target = "sb-actions"

pub fn links() {
  html.div([attr.id(links_target), attr.class("contents")], [])
}

pub fn actions() {
  html.div([attr.id(actions_target), attr.class("contents")], [])
}

pub fn into_links(elements: List(Element(message))) {
  portal.to("#" <> links_target, [], elements)
}

pub fn into_actions(elements: List(Element(message))) {
  portal.to("#" <> actions_target, [], elements)
}
