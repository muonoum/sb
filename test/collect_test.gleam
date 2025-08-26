import pprint
import sb/collect
import sb/error
import sb/report

pub fn collect_test() {
  collect.run(fn() {
    use a <- collect.try(zero: "", value: report.error(error.Message("a")))
    use b <- collect.require(report.error(error.Message("b")))
    collect.succeed(#(a, b))
  })
  |> report.error_context(error.Message("c"))
  |> pprint.debug
}
