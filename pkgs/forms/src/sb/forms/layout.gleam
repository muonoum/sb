import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/result
import sb/extra/function.{return}
import sb/extra/report.{type Report}
import sb/extra/state
import sb/forms/decoder
import sb/forms/error.{type Error}
import sb/forms/props
import sb/forms/zero.{type Zero}

pub type Results =
  List(Result(String, Report(Error)))

pub type Layout {
  Results(results: Results)
  Ids(results: Results, ids: List(String))
  // TODO: Hvordan håndtere styling? Tailwind-klasser vil være problematisk siden
  // de inkluderes basert på bruk ved bygging. Kun standard CSS/inline-styles?
  Grid(results: Results, areas: List(String), style: Dict(String, String))
}

pub fn decoder(results: Results) -> Zero(Layout) {
  use dynamic <- zero.new(Results(results))

  use <- result.lazy_or(
    decoder.run(dynamic, decode.list(decode.string))
    |> result.map(Ids(results:, ids: _)),
  )

  use <- return(props.decode(dynamic, _))
  use dict <- props.get_dict

  case dict.to_list(dict) {
    [#("grid", dynamic)] ->
      props.decode(dynamic, grid_decoder(results))
      |> state.from_result

    [#(unknown, _)] -> state.error(report.new(error.UnknownKind(unknown)))
    bad -> state.error(report.new(error.bad_format(bad)))
  }
}

fn grid_decoder(results: Results) -> props.Try(Layout) {
  use areas <- props.get("areas", decoder.from(decode.list(decode.string)))

  use style <- props.try("style", {
    zero.lazy(dict.new, decoder.from(decode.dict(decode.string, decode.string)))
  })

  state.ok(Grid(results, areas:, style:))
}
