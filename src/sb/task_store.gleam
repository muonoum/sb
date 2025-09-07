import filepath
import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/list
import gleam/otp/actor
import gleam/otp/supervision
import gleam/result
import sb/extra/dots
import sb/extra/path
import sb/extra/report.{type Report}
import sb/extra/yaml
import sb/forms/custom
import sb/forms/error.{type Error}
import sb/forms/file
import sb/forms/props
import sb/forms/task.{type Task}

const start_timeout = 10_000

const call_timeout = 1000

const shutdown_timeout = 1000

pub type Config {
  Config(prefix: String, pattern: String, interval: Int)
}

pub opaque type Model {
  Model(tasks: Dict(String, Task), errors: List(Report(Error)))
}

pub opaque type Message {
  Schedule(process.Subject(Message))
  Load(process.Subject(Message))
  GetTasks(process.Subject(List(Task)))
  GetTask(process.Subject(Result(Task, Nil)), String)
  GetErrors(process.Subject(List(Report(Error))))
}

pub fn get_task(
  store: process.Subject(Message),
  id: String,
) -> Result(Task, Report(Error)) {
  process.call(store, call_timeout, GetTask(_, id))
  |> report.replace_error(error.BadId(id))
}

pub fn get_tasks(store: process.Subject(Message)) -> List(Task) {
  process.call(store, call_timeout, GetTasks)
}

pub fn get_errors(store: process.Subject(Message)) -> List(Report(Error)) {
  process.call(store, call_timeout, GetErrors)
}

pub fn start(
  name: process.Name(Message),
  config: Config,
) -> Result(actor.Started(process.Subject(Message)), actor.StartError) {
  actor.new_with_initialiser(start_timeout, init)
  |> actor.named(name)
  |> actor.on_message(update(config))
  |> actor.start
}

pub fn supervised(
  name: process.Name(Message),
  config: Config,
) -> supervision.ChildSpecification(process.Subject(Message)) {
  supervision.ChildSpecification(
    start: fn() { start(name, config) },
    restart: supervision.Permanent,
    significant: False,
    child_type: supervision.Worker(shutdown_timeout),
  )
}

pub fn init(
  subject: process.Subject(Message),
) -> Result(actor.Initialised(Model, Message, process.Subject(Message)), String) {
  let model = Model(tasks: dict.new(), errors: [])
  process.send(subject, Load(subject))
  Ok(actor.initialised(model) |> actor.returning(subject))
}

fn update(config: Config) {
  fn(model: Model, message: Message) -> actor.Next(Model, Message) {
    case message {
      Schedule(store) -> schedule(model, config, store)
      Load(store) -> load(model, config) |> schedule(config, store)

      GetTasks(reply) -> {
        process.send(reply, dict.values(model.tasks))
        actor.continue(model)
      }

      GetTask(reply, id) -> {
        process.send(reply, dict.get(model.tasks, id))
        actor.continue(model)
      }

      GetErrors(reply) -> {
        process.send(reply, model.errors)
        actor.continue(model)
      }
    }
  }
}

fn schedule(
  model: Model,
  config: Config,
  store: process.Subject(Message),
) -> actor.Next(Model, Message) {
  case config.interval {
    0 -> actor.continue(model)

    interval -> {
      process.send_after(store, interval, Load(store))
      actor.continue(model)
    }
  }
}

// TODO: IndexContext
fn load(_model: Model, config: Config) -> Model {
  let #(files, file_errors) =
    result.partition({
      use path <- list.map(path.wildcard(config.prefix, config.pattern))

      use dynamic <- result.try(
        yaml.decode_file(filepath.join(config.prefix, path))
        |> report.map_error(error.YamlError)
        |> report.error_context(error.PathContext(path)),
      )

      use docs <- result.try(
        decode.run(dynamic, decode.list(decode.dynamic))
        |> report.map_error(error.DecodeError)
        |> report.error_context(error.PathContext(path)),
      )

      case docs {
        [] -> report.error(error.EmptyFile)

        [header, ..docs] -> {
          props.decode(dots.split(header), file.kind_decoder())
          |> result.map(file.File(kind: _, path:, docs:))
          |> report.error_context(error.PathContext(path))
        }
      }
    })

  let #(tasks, task_errors) = {
    let #(filters, filter_errors) = {
      let #(custom, errors) =
        result.partition(
          list.flatten(list.filter_map(files, file.filters))
          |> list.map(custom.decode),
        )

      #(custom.Filters(list.fold(custom, dict.new(), dict.merge)), errors)
    }

    let #(fields, field_errors) = {
      let #(custom, errors) =
        result.partition(
          list.flatten(list.filter_map(files, file.fields))
          |> list.map(custom.decode),
        )

      #(custom.Fields(list.fold(custom, dict.new(), dict.merge)), errors)
    }

    let #(sources, source_errors) = {
      let #(custom, errors) =
        result.partition(
          list.flatten(list.filter_map(files, file.sources))
          |> list.map(custom.decode),
        )

      #(custom.Sources(list.fold(custom, dict.new(), dict.merge)), errors)
    }

    let #(tasks, task_errors) =
      result.partition({
        let docs = list.flatten(list.filter_map(files, file.tasks))
        list.map(docs, props.decode(_, task.decoder(fields, sources, filters)))
      })

    let errors =
      task_errors
      |> list.append(filter_errors)
      |> list.append(field_errors)
      |> list.append(source_errors)

    #(tasks, errors)
  }

  let tasks =
    dict.from_list({
      use task <- list.map(tasks)
      #(task.id, task)
    })

  let errors = list.append(file_errors, task_errors)
  Model(tasks:, errors:)
}
