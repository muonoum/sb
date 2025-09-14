import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/result
import sb/extra/report.{type Report}
import sb/extra/state_eval as state
import sb/forms/decoder
import sb/forms/error.{type Error}
import sb/forms/props
import sb/forms/zero

pub type Results =
  List(Result(String, Report(Error)))

pub type Layout {
  Results(results: Results)
  Ids(results: Results, ids: List(String))
  Grid(results: Results, areas: List(String), style: Dict(String, String))
}

pub fn decoder(
  results: Results,
  dynamic: Dynamic,
) -> Result(Layout, Report(Error)) {
  use <- result.lazy_or(
    decoder.run(dynamic, decode.list(decode.string))
    |> result.map(Ids(results:, ids: _)),
  )

  props.decode(dynamic, {
    use grid <- props.get("grid", {
      decoder.from(decode.dict(decode.string, decode.dynamic))
    })

    use <- state.do(props.replace(grid))
    use areas <- props.get("areas", decoder.from(decode.list(decode.string)))

    use style <- props.try("style", {
      zero.lazy(
        dict.new,
        decoder.from(decode.dict(decode.string, decode.string)),
      )
    })

    props.succeed(Grid(results, areas:, style:))
  })
}
