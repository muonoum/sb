import extra/dots
import extra/yaml
import gleam/dict
import gleam/dynamic/decode
import gleeunit
import gleeunit/should
import pprint
import sb/inspect
import sb/task.{type Task}

pub fn main() -> Nil {
  gleeunit.main()
}

fn load_task(path: String) -> Task {
  let dynamic =
    yaml.decode_file(path)
    |> should.be_ok

  let assert [doc, ..] =
    decode.run(dynamic, decode.list(decode.dynamic))
    |> should.be_ok

  dots.split(doc)
  |> task.decoder(dict.new(), dict.new())
  |> should.be_ok
  |> pprint.debug
}

pub fn decode_test() {
  load_task("test_data/task1.yaml")
  |> inspect.inspect_task
}
