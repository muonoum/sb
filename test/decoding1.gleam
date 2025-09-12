import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/result
import inspect
import pprint
import sb/extra/dots
import sb/extra/yaml
import sb/forms/custom
import sb/forms/props
import sb/forms/task

pub fn main() {
  let task_data = load_document("test_data/task3.yaml")

  let assert Ok(custom_fields) =
    load_custom("test_data/fields.yaml")
    |> result.map(custom.Fields)

  let assert Ok(custom_sources) =
    load_custom("test_data/sources.yaml")
    |> result.map(custom.Sources)

  let assert Ok(custom_filters) =
    load_custom("test_data/filters.yaml")
    |> result.map(custom.Filters)

  let decoder = task.decoder(custom_filters, custom_fields, custom_sources)

  case props.decode(task_data, decoder) {
    Ok(task) -> {
      {
        use result <- list.each(task.layout)
        pprint.debug(result)
      }

      {
        use _id, field <- dict.map_values(task.fields)
        pprint.debug(field.kind)
      }

      inspect.inspect_task(task)

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
  use dict, dynamic <- list.try_fold(docs, dict.new())
  use custom <- result.try(custom.decode(dots.split(dynamic)))
  Ok(dict.merge(dict, custom))
}
