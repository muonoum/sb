import gleam/option.{type Option, None, Some}
import lustre/attribute as attr
import lustre/element.{type Element}
import lustre/element/html
import sb/extra/report.{type Report}
import sb/forms/error.{type Error}
import sb/forms/source.{type Source}
import sb/forms/value.{type Value}
import sb/frontend/components/core

pub type Config {
  Config(
    source: Result(Source, Report(Error)),
    value: Option(Result(Value, Report(Error))),
    is_loading: fn(Source) -> Bool,
    debug: Bool,
  )
}

pub fn field(config: Config) -> Element(message) {
  case config.value {
    Some(Ok(value)) -> core.inspect([], value)
    Some(Error(..)) | None -> view_source(config)
  }
}

fn view_source(config: Config) -> Element(message) {
  case config.source, config.debug {
    Error(report), _debug -> core.inspect([attr.class("text-red-800")], report)

    Ok(source), False ->
      html.div([attr.class("p-3 self-center")], [
        core.spinner([], config.is_loading(source)),
      ])

    Ok(source), True ->
      html.div([attr.class("flex gap-2")], [
        core.inspect([], source),
        core.spinner([], config.is_loading(source)),
      ])
  }
}
