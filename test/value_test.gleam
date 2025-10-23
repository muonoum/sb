import gleeunit/should
import sb/forms/value

pub fn to_string_test() {
  // TODO: Pair, List, Object
  // TODO: Pretty-print + snapshots

  value.Null |> value.to_string |> should.equal("null")
  value.String("test") |> value.to_string |> should.equal("test")
  value.Int(10) |> value.to_string |> should.equal("10")
  value.Float(3.14) |> value.to_string |> should.equal("3.14")
  value.Bool(True) |> value.to_string |> should.equal("true")
  value.Bool(False) |> value.to_string |> should.equal("false")
}

pub fn keys_test() {
  value.String("a") |> value.keys |> should.be_error

  value.List([value.String("a")])
  |> value.keys
  |> should.be_ok
  |> should.equal([value.String("a")])

  value.List([value.Pair("a", value.Null)])
  |> value.keys
  |> should.be_ok
  |> should.equal([value.String("a")])

  value.List([value.Pair("a", value.Null), value.String("b")])
  |> value.keys
  |> should.be_ok
  |> should.equal([value.String("a"), value.String("b")])

  value.Pair("k", value.String("v"))
  |> value.keys
  |> should.be_error

  value.Object([#("k", value.String("v"))])
  |> value.keys
  |> should.be_ok
  |> should.equal([value.String("k")])
}

pub fn key_test() {
  let same_key = fn(value) { value.key(value) |> should.equal(value) }

  same_key(value.Bool(False))
  same_key(value.Bool(True))
  same_key(value.Float(3.14))
  same_key(value.Int(10))
  same_key(value.List([value.String("a"), value.String("b")]))
  same_key(value.Null)
  same_key(value.Object([#("a", value.String("b"))]))
  same_key(value.String("key"))

  value.Pair("key", value.String("value"))
  |> value.key
  |> should.equal(value.String("key"))
}
