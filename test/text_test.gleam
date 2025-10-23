import gleam/dynamic
import gleeunit/should
import sb/forms/text

pub fn id_test() {
  // ok
  text.id_decoder(dynamic.string("10")) |> should.be_ok
  text.id_decoder(dynamic.string("10abc")) |> should.be_ok
  text.id_decoder(dynamic.string("abc10")) |> should.be_ok
  text.id_decoder(dynamic.string("some-id")) |> should.be_ok
  text.id_decoder(dynamic.string("some_id")) |> should.be_ok

  // feil type
  text.id_decoder(dynamic.int(10)) |> should.be_error
  text.id_decoder(dynamic.bool(True)) |> should.be_error

  // feil format
  text.id_decoder(dynamic.string("with space")) |> should.be_error
  text.id_decoder(dynamic.string("_hei")) |> should.be_error
}
