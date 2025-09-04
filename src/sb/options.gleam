import extra/state
import gleam/bool
import gleam/dict
import gleam/dynamic/decode
import gleam/list
import gleam/option.{None}
import gleam/result
import gleam/set.{type Set}
import sb/choice.{type Choice}
import sb/decoder
import sb/error.{type Error}
import sb/handlers
import sb/props.{type Props}
import sb/report.{type Report}
import sb/reset.{type Reset}
import sb/scope.{type Scope}
import sb/source.{type Source}
import sb/value.{type Value}

pub opaque type Options {
  SingleSource(Reset(Result(Source, Report(Error))))
  SourceGroups(List(Group))
}

pub type Group {
  Group(label: String, source: Reset(Result(Source, Report(Error))))
}

pub fn zero() -> Options {
  from_source(source.Literal(value.Null))
}

pub fn from_source(source: Source) -> Options {
  SingleSource(reset.try_new(Ok(source), source.refs))
}

pub fn from_groups(groups: List(#(String, Source))) -> Options {
  SourceGroups({
    use #(label, source) <- list.map(groups)
    Group(label:, source: reset.try_new(Ok(source), source.refs))
  })
}

pub fn sources(options: Options) -> List(Reset(Result(Source, Report(Error)))) {
  case options {
    SingleSource(source) -> [source]

    SourceGroups(groups) -> {
      use Group(_label, source) <- list.map(groups)
      source
    }
  }
}

pub fn reset(options: Options, refs: Set(String)) -> Options {
  case options {
    SingleSource(source) -> SingleSource(reset.maybe(source, refs))

    SourceGroups(groups) ->
      SourceGroups({
        use group <- list.map(groups)
        Group(..group, source: reset.maybe(group.source, refs))
      })
  }
}

pub fn evaluate(options: Options, scope: Scope) -> Options {
  case options {
    SingleSource(source) ->
      SingleSource({
        use source <- reset.map(source)
        use source <- result.try(source)
        source.evaluate(source, scope, search: None, handlers: handlers.empty())
      })

    SourceGroups(groups) ->
      SourceGroups({
        use Group(label, source) <- list.map(groups)

        Group(label, {
          use source <- reset.map(source)
          use source <- result.try(source)

          source.evaluate(
            source,
            scope,
            search: None,
            handlers: handlers.empty(),
          )
        })
      })
  }
}

pub fn select(options: Options, value: Value) -> Result(Choice, Report(Error)) {
  case options {
    SourceGroups(groups) -> {
      let error = report.error(error.BadValue(value))
      use result, Group(source:, ..) <- list.fold(groups, error)
      use <- result.lazy_or(result)
      select(SingleSource(source), value)
    }

    SingleSource(source) ->
      case reset.unwrap(source) {
        Ok(source.Literal(value.List(choices))) ->
          select_list(value, choices)
          |> report.replace_error(error.BadValue(value))

        Ok(source.Literal(value.Object(choices))) ->
          select_object(value, choices)
          |> report.replace_error(error.BadValue(value))

        _source -> report.error(error.BadSource)
      }
  }
}

fn select_list(want: Value, choices: List(Value)) -> Result(Choice, Nil) {
  use have <- list.find_map(choices)
  use <- bool.guard(have != want, Error(Nil))
  Ok(choice.new(have, have))
}

fn select_object(
  want: Value,
  choices: List(#(String, Value)),
) -> Result(Choice, Nil) {
  use want <- result.try(value.to_string(want))
  use #(have, value) <- list.find_map(choices)
  use <- bool.guard(have != want, Error(Nil))
  Ok(choice.new(value.String(have), value))
}

pub fn decoder() -> Props(Options) {
  use dict <- props.get_dict()

  case dict.to_list(dict) {
    [#("groups", dynamic)] ->
      decoder.run(dynamic, decode.list(decode.dynamic))
      |> result.try(list.try_map(_, props.decode(_, group_decoder())))
      |> result.map(SourceGroups)
      |> state.from_result

    _else ->
      state.map(source.decoder(), Ok)
      |> state.attempt(state.catch_error)
      |> state.map(reset.try_new(_, source.refs))
      |> state.map(SingleSource)
  }
}

fn group_decoder() -> Props(Group) {
  use label <- props.required("label", {
    decoder.zero_string(decoder.from(decode.string))
  })

  use source <- props.required("source", {
    use <- decoder.zero(
      props.decode(_, {
        state.map(source.decoder(), Ok)
        |> state.attempt(state.catch_error)
        |> state.map(reset.try_new(_, source.refs))
      }),
    )

    reset.try_new(Ok(source.zero()), source.refs)
  })

  state.succeed(Group(label:, source:))
}
