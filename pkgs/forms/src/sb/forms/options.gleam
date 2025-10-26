import gleam/bool
import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/set.{type Set}
import sb/extra/function.{compose, return}
import sb/extra/list as list_extra
import sb/extra/reader.{type Reader}
import sb/extra/report.{type Report}
import sb/extra/reset
import sb/extra/state
import sb/forms/choice.{type Choice}
import sb/forms/custom
import sb/forms/decoder
import sb/forms/error.{type Error}
import sb/forms/evaluate
import sb/forms/props
import sb/forms/source.{type Source}
import sb/forms/value.{type Value}

pub type Options {
  SingleSource(source.Resetable)
  SourceGroups(List(Group))
}

pub type Group {
  Group(label: String, source: source.Resetable)
}

pub fn unique_keys(options: Options) -> Result(List(Value), Report(Error)) {
  use <- return(report.map_error(_, error.DuplicateKeys))
  use <- return(compose(list.flatten, list_extra.unique))
  use source <- list.filter_map(sources(options))

  case reset.unwrap(source) {
    Ok(source.Literal(value)) -> value.keys(value)
    Ok(..) -> Error(Nil)
    Error(..) -> Error(Nil)
  }
}

pub fn sources(options: Options) -> List(source.Resetable) {
  case options {
    SingleSource(source) -> [source]

    SourceGroups(groups) -> {
      use Group(_label, source) <- list.map(groups)
      source
    }
  }
}

pub fn is_loading(options: Options, check: fn(Source) -> Bool) -> Bool {
  let unwrap = fn(source) {
    case reset.unwrap(source) {
      Ok(source) -> check(source)
      Error(_report) -> False
    }
  }

  case options {
    SingleSource(source) -> unwrap(source)

    SourceGroups(groups) -> {
      use Group(_label, source) <- list.any(groups)
      unwrap(source)
    }
  }
}

pub fn reset(options: Options, refs: Set(String)) -> Options {
  case options {
    SingleSource(source) -> SingleSource(reset.maybe(source, refs))

    SourceGroups(groups) ->
      SourceGroups({
        use Group(label:, source:) <- list.map(groups)
        Group(label:, source: reset.maybe(source, refs))
      })
  }
}

pub fn evaluate(
  options: Options,
  search: Option(String),
) -> Reader(Options, evaluate.Context) {
  let evaluate = fn(source) {
    use source <- evaluate.reset(source)

    case source {
      Error(report) -> reader.return(Error(report))
      Ok(source) -> source.evaluate(source, search)
    }
  }

  case options {
    SingleSource(source) -> reader.map(evaluate(source), SingleSource)

    SourceGroups(groups) -> {
      use <- return(compose(reader.sequence, reader.map(_, SourceGroups)))
      use Group(label:, source:) <- list.map(groups)
      use source <- reader.bind(evaluate(source))
      reader.return(Group(label:, source:))
    }
  }
}

pub fn select(options: Options, target: Value) -> Result(Choice, Report(Error)) {
  case options {
    SourceGroups(groups) -> {
      let error = report.error(error.BadValue(target))
      use result, Group(source:, ..) <- list.fold(groups, error)
      use <- result.lazy_or(result)
      SingleSource(source) |> select(target)
    }

    SingleSource(source) ->
      case reset.unwrap(source) {
        Ok(source.Literal(value.List(choices))) -> {
          use <- return(report.replace_error(_, error.BadValue(target)))
          use value <- list.find_map(choices)
          let choice = choice.from_value(value)
          use <- bool.guard(choice.key(choice) != target, Error(Nil))
          Ok(choice)
        }

        Ok(source.Literal(value.Object(choices))) -> {
          use <- return(report.replace_error(_, error.BadValue(target)))
          use #(key, value) <- list.find_map(choices)
          let key = value.String(key)
          use <- bool.guard(key != target, Error(Nil))
          Ok(choice.new(key, value))
        }

        _source -> report.error(error.BadSource)
      }
  }
}

// TODO: Duplicate keys?

pub fn decoder(
  dynamic: Dynamic,
  sources sources: custom.Sources,
) -> Result(Options, Report(Error)) {
  let decoder = decode.dict(decode.string, decode.dynamic)

  case decode.run(dynamic, decoder) |> result.map(dict.to_list) {
    Ok([#("groups", dynamic)]) -> {
      use list <- result.try(decoder.run(dynamic, decode.list(decode.dynamic)))
      use <- return(result.map(_, SourceGroups))
      list.try_map(list, props.decode(_, group_decoder(sources:)))
    }

    Ok(..) | Error(..) ->
      source.decoder(dynamic, sources:)
      |> result.map(SingleSource)
  }
}

fn group_decoder(sources sources: custom.Sources) -> props.Try(Group) {
  use label <- props.get("label", decoder.from(decode.string))
  use source <- props.get("source", source.decoder(_, sources:))
  state.ok(Group(label:, source:))
}
