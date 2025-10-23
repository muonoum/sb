import gleeunit/should
import sb/extra/duration as duration_extra
import sb/extra/parser

pub fn duration_test() {
  parser.parse_string("10ms", duration_extra.parser())
  |> should.be_ok
  |> should.equal(10)

  parser.parse_string("10s", duration_extra.parser())
  |> should.be_ok
  |> should.equal(10_000)

  parser.parse_string("10m", duration_extra.parser())
  |> should.be_ok
  |> should.equal(600_000)

  parser.parse_string("10k", duration_extra.parser())
  |> should.be_error

  parser.parse_string("10mss", duration_extra.parser())
  |> should.be_error

  parser.parse_string("k0s", duration_extra.parser())
  |> should.be_error
}
