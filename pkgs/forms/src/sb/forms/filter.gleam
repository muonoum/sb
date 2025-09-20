import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/regexp.{type Regexp}
import gleam/result
import sb/extra/report.{type Report}
import sb/extra/state
import sb/forms/decoder
import sb/forms/error.{type Error}
import sb/forms/props.{type Props}
import sb/forms/value.{type Value}
import sb/forms/zero

pub const builtin = [
  "succeed", "fail", "expect", "regex-match", "regex-replace", "parse-integer",
  "parse-float",
]

const succeed_keys = []

const fail_keys = ["error-message"]

const expect_keys = ["value", "error-message"]

const regex_match_keys = ["pattern", "case-sensitive", "error-message"]

const regex_replace_keys = [
  "pattern",
  "case-sensitive",
  "replacements",
  "error-message",
]

const parse_integer_keys = []

const parse_float_keys = []

pub type Filter {
  Succeed
  Fail(error_message: String)
  Expect(value: Value, error_message: Option(String))

  RegexMatch(pattern: Regexp, error_message: Option(String))

  RegexReplace(
    pattern: Regexp,
    replacements: List(String),
    error_message: Option(String),
  )

  ParseInteger
  ParseFloat
}

pub fn evaluate(value: Value, filter: Filter) -> Result(Value, Report(Error)) {
  case filter {
    Succeed -> Ok(value)

    Fail(error_message:) -> report.error(error.Message(error_message))

    Expect(value: expected, error_message:) ->
      case expected == value, error_message {
        True, _error_message -> Ok(value)
        False, Some(error_message) -> report.error(error.Message(error_message))

        False, None ->
          report.error(error.BadValue(value))
          |> report.error_context(error.Expected(expected))
      }

    RegexMatch(pattern:, error_message:) ->
      case value {
        value.String(string) ->
          case regexp.check(pattern, string), error_message {
            True, _error_message -> Ok(value)
            False, None -> report.error(error.NotFound(string))
            False, Some(error_message) ->
              report.error(error.Message(error_message))
          }

        value -> report.error(error.BadValue(value))
      }

    RegexReplace(pattern: _, replacements: _, error_message: _) ->
      case value {
        value.String(_string) ->
          report.error(error.Todo("evaluate regex replace"))
        value -> report.error(error.BadValue(value))
      }

    ParseInteger ->
      case value {
        value.String(string) ->
          int.parse(string)
          |> report.replace_error(error.BadValue(value))
          |> result.map(value.Int)

        value.Int(_) -> Ok(value)
        value -> report.error(error.BadValue(value))
      }

    ParseFloat ->
      case value {
        value.String(string) ->
          float.parse(string)
          |> report.replace_error(error.BadValue(value))
          |> result.map(value.Float)

        value.Float(_) -> Ok(value)
        value.Int(int) -> Ok(value.Float(int.to_float(int)))
        value -> report.error(error.BadValue(value))
      }
  }
}

pub fn decoder(
  name: String,
  check_keys: fn(List(String)) -> Props(Nil),
) -> props.Try(Filter) {
  case name {
    "succeed" ->
      state.do(check_keys(succeed_keys), succeed_decoder)
      |> props.error_context(error.BadKind(name))

    "fail" ->
      state.do(check_keys(fail_keys), fail_decoder)
      |> props.error_context(error.BadKind(name))

    "expect" ->
      state.do(check_keys(expect_keys), expect_decoder)
      |> props.error_context(error.BadKind(name))

    "regex-match" ->
      state.do(check_keys(regex_match_keys), regex_match_decoder)
      |> props.error_context(error.BadKind(name))

    "regex-replace" ->
      state.do(check_keys(regex_replace_keys), regex_replace_decoder)
      |> props.error_context(error.BadKind(name))

    "parse-integer" ->
      state.do(check_keys(parse_integer_keys), parse_integer_decoder)
      |> props.error_context(error.BadKind(name))

    "parse-float" ->
      state.do(check_keys(parse_float_keys), parse_float_decoder)
      |> props.error_context(error.BadKind(name))

    unknown -> state.error(report.new(error.UnknownKind(unknown)))
  }
}

fn succeed_decoder() -> props.Try(Filter) {
  state.ok(Succeed)
}

fn fail_decoder() -> props.Try(Filter) {
  use error_message <- props.get("error-message", decoder.from(decode.string))
  state.ok(Fail(error_message:))
}

fn expect_decoder() -> props.Try(Filter) {
  use value <- props.get("value", decoder.from(value.decoder()))

  use error_message <- props.try("error-message", {
    zero.option(decoder.from(decode.string))
  })

  state.ok(Expect(value:, error_message:))
}

fn regex_match_decoder() -> props.Try(Filter) {
  use case_insensitive <- props.try("case-insensitive", {
    zero.bool(decoder.from(decode.bool))
  })

  use pattern <- props.get("pattern", regex_decoder(case_insensitive))

  use error_message <- props.try("error-message", {
    zero.option(decoder.from(decode.string))
  })

  state.ok(RegexMatch(pattern:, error_message:))
}

fn regex_replace_decoder() -> props.Try(Filter) {
  use case_insensitive <- props.try("case-insensitive", {
    zero.bool(decoder.from(decode.bool))
  })

  use pattern <- props.get("pattern", regex_decoder(case_insensitive))

  use replacements <- props.get("replacements", {
    decoder.from(decode.list(decode.string))
  })

  use error_message <- props.try("error-message", {
    zero.option(decoder.from(decode.string))
  })

  state.ok(RegexReplace(pattern:, replacements:, error_message:))
}

fn parse_integer_decoder() -> props.Try(Filter) {
  state.ok(ParseInteger)
}

fn parse_float_decoder() -> props.Try(Filter) {
  state.ok(ParseFloat)
}

fn regex_decoder(
  case_insensitive: Bool,
) -> fn(Dynamic) -> Result(Regexp, Report(Error)) {
  fn(dynamic) {
    use string <- result.try(decoder.run(dynamic, decode.string))

    regexp.Options(case_insensitive:, multi_line: False)
    |> regexp.compile(string, _)
    |> report.map_error(error.RegexError)
  }
}
