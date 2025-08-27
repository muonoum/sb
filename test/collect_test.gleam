import pprint
import sb/collect
import sb/error
import sb/report

pub fn collect_test() {
  collect.run(fn() {
    use a <- collect.try(zero: "", value: Ok("a"))
    use b <- collect.require(Ok([]))
    collect.succeed(#(a, b))
  })
  |> report.error_context(error.Message("c"))
  |> pprint.debug
}
