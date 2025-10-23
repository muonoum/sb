import gleeunit/should
import sb/extra/list as list_extra

pub fn unique_test() {
  list_extra.unique(["a", "b", "c", "b", "c", "d"])
  |> should.be_error
  |> should.equal(["b", "c"])

  list_extra.unique(["a", "b", "c", "d"])
  |> should.be_ok
  |> should.equal(["a", "b", "c", "d"])
}
