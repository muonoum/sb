import gleam/bool
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regexp.{type Regexp}
import gleam/result
import gleam/string
import sb/extra/function.{compose, identity, return}
import sb/extra/report.{type Report}
import sb/extra/state
import sb/forms/decoder
import sb/forms/error.{type Error}
import sb/forms/handlers.{type Handlers}
import sb/forms/props
import sb/forms/value.{type Value}
import sb/forms/zero

pub const builtin = [
  "succeed",
  "fail",
  "expect",
  "regex-match",
  "regex-replace",
  "parse-integer",
  "parse-float",
  "split-string",
  "trim-space",
  "from-json",
  "to-json",
  "jq",
]

const succeed_keys = ["value"]

const fail_keys = ["error-message"]

const expect_keys = ["value", "error-message"]

const regex_match_keys = ["pattern", "case-sensitive", "error-message"]

const regex_replace_keys = [
  "pattern",
  "case-sensitive",
  "replacements",
  "error-message",
]

const split_string_keys = ["on", "trim"]

const trim_space_keys = ["start", "end"]

const jq_keys = ["expression"]

pub type Filter {
  Succeed(value: Option(Value))
  Fail(error_message: String)
  Expect(value: Value, error_message: Option(String))
  RegexMatch(pattern: Regexp, error_message: Option(String))

  RegexReplace(
    pattern: Regexp,
    replacements: List(String),
    error_message: Option(String),
  )

  ParseFloat
  ParseInteger
  SplitString(on: String, trim: fn(String) -> String)
  TrimSpace(trim: fn(String) -> String)
  Jq(String)
  FromJson
  ToJson
}

pub fn evaluate(
  value: Value,
  filter: Filter,
  handlers handlers: Handlers,
) -> Result(Value, Report(Error)) {
  use <- return(report.error_context(_, error.BadFilter))

  case filter {
    Succeed(Some(value)) -> Ok(value)
    Succeed(None) -> Ok(value)

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
            False, None -> report.error(error.Unmatched(string))
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

    ParseInteger ->
      case value {
        value.String(string) ->
          int.parse(string)
          |> report.replace_error(error.BadValue(value))
          |> result.map(value.Int)

        value.Int(_) -> Ok(value)
        value -> report.error(error.BadValue(value))
      }

    // TODO: Trim empty?
    SplitString(on:, trim:) -> {
      case value {
        value.String(string) ->
          string.split(string, on:)
          |> list.map(trim)
          |> list.map(value.String)
          |> value.List
          |> Ok

        _value -> report.error(error.BadValue(value))
      }
    }

    TrimSpace(trim:) ->
      case value {
        value.String(string) -> Ok(value.String(trim(string)))
        value -> report.error(error.BadValue(value))
      }

    Jq(expression) -> {
      let json = json.to_string(value.to_json(value))
      use string <- result.try(handlers.command(["jq", expression], Some(json)))

      dynamic.string(string)
      |> decoder.run(value.decoder())
    }

    FromJson ->
      case value {
        value.String(string) ->
          dynamic.string(string)
          |> decoder.run(value.decoder())

        value -> report.error(error.BadValue(value))
      }

    ToJson -> Ok(value.String(json.to_string(value.to_json(value))))
  }
}

pub fn decoder(
  name: String,
  check_keys: fn(List(String)) -> props.Try(Nil),
) -> props.Try(Filter) {
  use <- return(props.error_context(error.BadKind(name)))

  case name {
    "succeed" -> state.try_do(check_keys(succeed_keys), succeed_decoder)
    "fail" -> state.try_do(check_keys(fail_keys), fail_decoder)
    "expect" -> state.try_do(check_keys(expect_keys), expect_decoder)

    "regex-match" ->
      state.try_do(check_keys(regex_match_keys), regex_match_decoder)

    "regex-replace" ->
      state.try_do(check_keys(regex_replace_keys), regex_replace_decoder)

    "parse-float" -> state.ok(ParseFloat)
    "parse-integer" -> state.ok(ParseInteger)

    "split-string" ->
      state.try_do(check_keys(split_string_keys), split_string_decoder)

    "trim-space" ->
      state.try_do(check_keys(trim_space_keys), trim_space_decoder)

    "jq" -> state.try_do(check_keys(jq_keys), jq_decoder)
    "from-json" -> state.ok(FromJson)
    "to-json" -> state.ok(ToJson)

    unknown -> state.error(report.new(error.UnknownKind(unknown)))
  }
}

fn succeed_decoder() -> props.Try(Filter) {
  use value <- props.try("value", zero.option(decoder.from(value.decoder())))
  state.ok(Succeed(value:))
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

fn regex_decoder(
  case_insensitive: Bool,
) -> fn(Dynamic) -> Result(Regexp, Report(Error)) {
  use dynamic <- identity
  use string <- result.try(decoder.run(dynamic, decode.string))

  regexp.Options(case_insensitive:, multi_line: False)
  |> regexp.compile(string, _)
  |> report.map_error(error.RegexError)
}

fn split_string_decoder() -> props.Try(Filter) {
  use on <- props.get("on", decoder.from(decode.string))
  use trim <- props.try("trim", zero.new(True, decoder.from(decode.bool)))

  use <- return(compose(SplitString(on:, trim: _), state.ok))
  use <- bool.guard(trim, string.trim)
  identity
}

fn trim_space_decoder() -> props.Try(Filter) {
  use start <- props.try("start", zero.new(True, decoder.from(decode.bool)))
  use end <- props.try("end", zero.new(True, decoder.from(decode.bool)))

  use <- return(compose(TrimSpace(trim: _), state.ok))
  use <- bool.guard(start && end, string.trim)
  use <- bool.guard(start, string.trim_start)
  use <- bool.guard(end, string.trim_end)
  identity
}

fn jq_decoder() -> props.Try(Filter) {
  use expression <- props.get("expression", decoder.from(decode.string))
  state.ok(Jq(expression))
}
