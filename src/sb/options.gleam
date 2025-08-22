import gleam/bool
import gleam/list
import gleam/result
import gleam/set.{type Set}
import sb/error.{type Error}
import sb/reset.{type Reset}
import sb/scope.{type Scope}
import sb/source.{type Source}
import sb/value.{type Value}

pub type Options {
  SingleSource(Reset(Result(Source, Error)))
  SourceGroups(List(Group))
}

pub type Group {
  Group(label: String, source: Reset(Result(Source, Error)))
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

pub fn reset2(options: Options, refs: Set(String)) -> #(Options, Bool) {
  case options {
    SingleSource(source) -> {
      let #(source, did_reset) = reset.maybe2(source, refs)
      #(SingleSource(source), did_reset)
    }

    SourceGroups(groups) -> #(
      SourceGroups({
        use group <- list.map(groups)
        Group(..group, source: reset.maybe(group.source, refs))
      }),
      False,
    )
  }
}

pub fn evaluate(options: Options, scope: Scope) -> Options {
  case options {
    SingleSource(source) ->
      SingleSource({
        use source <- reset.map(source)
        use source <- result.try(source)
        source.evaluate(source, scope)
      })

    SourceGroups(groups) ->
      SourceGroups({
        use Group(label, source) <- list.map(groups)

        Group(label, {
          use source <- reset.map(source)
          use source <- result.try(source)
          source.evaluate(source, scope)
        })
      })
  }
}

pub fn select(options: Options, value: Value) -> Result(Value, Error) {
  case options {
    SourceGroups(groups) -> {
      let error = Error(error.BadValue(value))
      use result, Group(source:, ..) <- list.fold(groups, error)
      use <- result.lazy_or(result)
      select(SingleSource(source), value)
    }

    SingleSource(source) ->
      case reset.unwrap(source) {
        Ok(source.Literal(value.List(choices))) ->
          select_list(value, choices)
          |> result.replace_error(error.BadValue(value))

        Ok(source.Literal(value.Object(choices))) ->
          select_object(value, choices)
          |> result.replace_error(error.BadValue(value))

        _source -> Error(error.BadSource)
      }
  }
}

fn select_list(want: Value, choices: List(Value)) -> Result(Value, Nil) {
  use have <- list.find(choices)
  have == want
}

fn select_object(
  want: Value,
  choices: List(#(String, Value)),
) -> Result(Value, Nil) {
  use want <- result.try(value.string(want))
  use #(have, value) <- list.find_map(choices)
  use <- bool.guard(have != want, Error(Nil))
  Ok(value)
}
