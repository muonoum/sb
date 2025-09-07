import lustre/effect.{type Effect}
import plinth/browser/element.{type Element}
import plinth/javascript/global

@external(javascript, "../glue.mjs", "get_shadow_element")
pub fn get_shadow_element(page: String, id: String) -> Result(Element, Nil)

@external(javascript, "../glue.mjs", "get_element")
pub fn get_element(id: String) -> Result(Element, Nil)

@external(javascript, "../glue.mjs", "scroll_to")
pub fn scroll_to(element: Element, x: Float, y: Float) -> Nil

@external(javascript, "../glue.mjs", "scroll_into_view")
pub fn scroll_into_view(element: Element) -> Nil

pub fn scroll_to_top(element: Element) -> Nil {
  scroll_to(element, 0.0, 0.0)
}

pub fn scroll_to_bottom(element: Element) -> Nil {
  let y = element.scroll_height(element)
  scroll_to(element, 0.0, y)
}

pub fn schedule(after: Int, message: message) -> Effect(message) {
  use dispatch <- effect.from
  let _ = global.set_timeout(after, fn() { dispatch(message) })
  Nil
}
