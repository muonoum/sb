import { Ok, Error } from "./gleam.mjs";

export function get_element(id) {
  let element = document.getElementById(id);
  if (!element) return new Error();
  return new Ok(element);
}

export function get_shadow_element(name, id) {
  let element = document.getElementById(name).shadowRoot.getElementById(id);
  if (!element) return new Error();
  return new Ok(element);
}

export function scroll_to(element, x, y) {
  element.scrollTo(x, y);
}

export function scroll_into_view(element) {
  element.scrollIntoView({ block: "start", inline: "nearest" });
}
