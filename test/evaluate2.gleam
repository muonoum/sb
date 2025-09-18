import gleam/dict
import gleam/dynamic/decode
import gleam/io
import sb/extra/dots
import sb/extra_server/yaml
import sb/forms/access
import sb/forms/custom
import sb/forms/debug
import sb/forms/props
import sb/forms/task

pub fn main() {
  let assert Ok(task) = {
    let assert Ok(dynamic) = yaml.decode_file("test_data/task2.yaml")
    let assert Ok([doc, ..]) = decode.run(dynamic, decode.list(decode.dynamic))

    dots.split(doc)
    |> props.decode(task.decoder(
      filters: custom.Filters(dict.new()),
      fields: custom.Fields(dict.new()),
      sources: custom.Sources(dict.new()),
      defaults: task.Defaults(
        category: [],
        runners: access.none(),
        approvers: access.none(),
      ),
    ))
  }

  debug.format_task(task)
  |> io.println
}
