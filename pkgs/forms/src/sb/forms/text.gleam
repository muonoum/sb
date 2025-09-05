import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import sb/extra/report.{type Report}
import sb/forms/error.{type Error}
import sb/forms/scope.{type Scope}
import sb/forms/value

import sb/extra/parser.{
  any, between, choice, drop, end, expect, grapheme, keep, label, many,
  not_followed_by, one_of, some, string, succeed,
}

pub type Text {
  Text(parts: List(Part))
}

pub type Part {
  Placeholder
  Reference(String)
  Static(String)
}

pub fn new(string: String) -> Result(Text, Report(Error)) {
  parse(string)
}

pub fn refs(text: Text) -> List(String) {
  use part <- list.filter_map(text.parts)

  case part {
    Placeholder -> Error(Nil)
    Reference(id) -> Ok(id)
    Static(_) -> Error(Nil)
  }
}

pub fn evaluate(
  text: Text,
  scope: Scope,
  placeholder placeholder: Option(String),
) -> Result(Option(String), Report(Error)) {
  evaluate_step(text.parts, scope, placeholder, "")
}

fn evaluate_step(
  parts: List(Part),
  scope: Scope,
  placeholder: Option(String),
  result: String,
) -> Result(Option(String), Report(Error)) {
  let next = fn(rest, string) {
    evaluate_step(rest, scope, placeholder, result <> string)
  }

  case parts, placeholder {
    [], _placeholder -> Ok(Some(result))
    [Static(string), ..rest], _placeholder -> next(rest, string)
    [Placeholder, ..rest], Some(string) -> next(rest, string)
    [Placeholder, ..], _placeholder -> Ok(None)

    [Reference(id), ..rest], _ ->
      case scope.value(scope, id) {
        Error(Nil) -> Ok(None)
        Ok(value.String(string)) -> next(rest, string)
        Ok(value) -> report.error(error.BadValue(value))
      }
  }
}

fn digit() {
  expect(string.contains("01234567890", _))
  |> label("base 10 digit")
}

fn lowercase() {
  expect(string.contains("abcdefghijklmnopqrstuvwxyz", _))
  |> label("lower case character")
}

fn uppercase() {
  expect(string.contains("ABCDEFGHIJKLMNOPQRSTUVWXYZ", _))
  |> label("upper case character")
}

fn alphanumeric() {
  one_of([lowercase(), uppercase(), digit()])
  |> label("alpha numeric character")
}

fn spaces() {
  many(grapheme(" "))
}

pub fn parse(source: String) -> Result(Text, Report(Error)) {
  let open = {
    use <- drop(label(string("{{"), "opening braces"))
    use <- drop(spaces())
    succeed(Nil)
  }

  let close = {
    use <- drop(spaces())
    use <- drop(label(string("}}"), "closing braces"))
    succeed(Nil)
  }

  let static = {
    use parts <- keep(
      some({
        use <- drop(not_followed_by(open))
        use grapheme <- keep(any())
        succeed(grapheme)
      }),
    )

    succeed(Static(string.join(parts, "")))
  }

  let reference = {
    let id = {
      use id <- keep(id_parser())
      succeed(Reference(id))
    }

    let placeholder = {
      use <- drop(grapheme("_"))
      succeed(Placeholder)
    }

    choice(label(placeholder, "placeholder"), label(id, "id"))
    |> between(open, close)
  }

  let template = {
    use parts <- keep(many(choice(reference, static)))
    use <- drop(end())
    succeed(parts)
  }

  parser.parse_string(source, template)
  |> report.map_error(error.TextError)
  |> result.map(Text)
}

fn id_parser() {
  let initial = alphanumeric()
  let symbol = choice(grapheme("-"), grapheme("_"))
  let subsequent = choice(symbol, alphanumeric())
  use first <- keep(initial)
  use rest <- keep(many(subsequent))
  succeed(string.join([first, ..rest], ""))
}

pub fn id_decoder(dynamic: Dynamic) -> Result(String, Report(Error)) {
  use string <- result.try(
    decode.run(dynamic, decode.string)
    |> report.map_error(error.DecodeError),
  )

  parser.parse_string(string, id_parser())
  |> report.map_error(error.TextError)
}

pub fn decoder(dynamic: Dynamic) -> Result(Text, Report(Error)) {
  decode.run(dynamic, decode.string)
  |> report.map_error(error.DecodeError)
  |> result.try(parse)
}
