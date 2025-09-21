import gleam/dynamic
import gleeunit/should
import sb/forms/text

pub fn id_test() {
  text.id_decoder(dynamic.string("10"))
  |> should.be_ok

  text.id_decoder(dynamic.int(10))
  |> should.be_error

  text.id_decoder(dynamic.bool(True))
  |> should.be_error

  text.id_decoder(dynamic.string("with space"))
  |> should.be_error

  text.id_decoder(dynamic.string("with-dash"))
  |> should.be_ok
}
