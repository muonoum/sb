import gleam/dynamic/decode.{type Decoder}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import sb/error.{type Error}
import sb/parser as p
import sb/report.{type Report}
import sb/scope.{type Scope}
import sb/value

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
  p.expect(string.contains("01234567890", _))
  |> p.label("base 10 digit")
}

fn lowercase() {
  p.expect(string.contains("abcdefghijklmnopqrstuvwxyz", _))
  |> p.label("lower case character")
}

fn uppercase() {
  p.expect(string.contains("ABCDEFGHIJKLMNOPQRSTUVWXYZ", _))
  |> p.label("upper case character")
}

fn alphanumeric() {
  p.one_of([lowercase(), uppercase(), digit()])
  |> p.label("alpha numeric character")
}

fn spaces() {
  p.many(p.grapheme(" "))
}

pub fn parse(source: String) -> Result(Text, Report(Error)) {
  let open = {
    use <- p.drop(p.label(p.string("{{"), "opening braces"))
    use <- p.drop(spaces())
    p.succeed(Nil)
  }

  let close = {
    use <- p.drop(spaces())
    use <- p.drop(p.label(p.string("}}"), "closing braces"))
    p.succeed(Nil)
  }

  let static = {
    use parts <- p.keep(
      p.some({
        use <- p.drop(p.not_followed_by(open))
        use grapheme <- p.keep(p.any())
        p.succeed(grapheme)
      }),
    )

    p.succeed(Static(string.join(parts, "")))
  }

  let reference = {
    let placeholder = {
      use <- p.drop(p.grapheme("_"))
      p.succeed(Placeholder)
    }

    let id = {
      let initial = lowercase()
      let symbol = p.choice(p.grapheme("-"), p.grapheme("_"))
      let subsequent = p.choice(symbol, alphanumeric())
      use first <- p.keep(initial)
      use rest <- p.keep(p.many(subsequent))
      p.succeed(Reference(string.join([first, ..rest], "")))
    }

    p.choice(p.label(placeholder, "placeholder"), p.label(id, "id"))
    |> p.between(open, close)
  }

  let template = {
    use parts <- p.keep(p.many(p.choice(reference, static)))
    use <- p.drop(p.end())
    p.succeed(parts)
  }

  p.parse_string(source, template)
  |> report.map_error(error.TextError)
  |> result.map(Text)
}

pub fn decoder() -> Decoder(Text) {
  use string <- decode.then(decode.string)

  case parse(string) {
    Error(..) -> decode.failure(Text([]), "text")
    Ok(text) -> decode.success(text)
  }
}
