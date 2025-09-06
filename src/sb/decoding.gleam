import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/result
import pprint
import sb/extra/dots
import sb/extra/yaml
import sb/forms/custom
import sb/forms/props
import sb/forms/task
import sb/inspect

pub fn main() {
  let task_data = load_document("test_data/task3.yaml")

  let assert Ok(custom_fields) =
    load_custom("test_data/fields.yaml")
    |> result.map(dict.from_list)
    |> result.map(custom.Fields)

  let custom_sources = custom.Sources(dict.new())
  let custom_filters = custom.Filters(dict.new())

  let decoder = task.decoder(custom_fields, custom_sources, custom_filters)
  case props.decode(task_data, decoder) {
    Ok(task) -> {
      {
        use _id, field <- dict.map_values(task.fields)
        pprint.debug(field.kind)
      }

      Nil
    }

    Error(report) -> {
      pprint.debug(report)
      Nil
    }
  }
}

fn load_document(path: String) -> Dynamic {
  let assert Ok(dynamic) = yaml.decode_file(path)
  let assert Ok([doc, ..]) = decode.run(dynamic, decode.list(decode.dynamic))
  dots.split(doc)
}

fn load_custom(path: String) {
  let assert Ok(dynamic) = yaml.decode_file(path)
  let assert Ok(docs) = decode.run(dynamic, decode.list(decode.dynamic))
  use doc <- list.try_map(docs)
  props.decode(dots.split(doc), custom.decoder())
}
