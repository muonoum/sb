import extra/dots
import extra/yaml
import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import sb/custom
import sb/inspect
import sb/props
import sb/task

pub fn main() {
  let dynamic = load_task("test_data/task1.yaml")

  let custom_fields =
    custom.Fields(
      dict.from_list([
        #(
          "mega",
          dict.from_list([
            #("kind", dynamic.string("data")),
            #(
              "source",
              dynamic.properties([
                #(dynamic.string("reference"), dynamic.string("a")),
              ]),
            ),
          ]),
        ),
      ]),
    )

  let custom_filters = custom.Filters(dict.new())

  let decoder = task.decoder(custom_fields, custom_filters)
  let assert Ok(task) = props.decode(dynamic, decoder)
  inspect.inspect_task(echo task)
}

fn load_task(path: String) -> Dynamic {
  let assert Ok(dynamic) = yaml.decode_file(path)
  let assert Ok([doc, ..]) = decode.run(dynamic, decode.list(decode.dynamic))
  dots.split(doc)
}
