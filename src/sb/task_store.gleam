import filepath
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/list
import gleam/otp/actor
import gleam/otp/supervision
import gleam/result
import sb/extra
import sb/extra/dots
import sb/extra/path
import sb/extra/report.{type Report}
import sb/extra/yaml
import sb/forms/custom.{type Custom}
import sb/forms/decoder
import sb/forms/error.{type Error}
import sb/forms/file.{type File, File}
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

fn load(model: Model, config: Config) -> Model {
  let #(files, model) = load_files(config, model)

  let #(tasks, files) = list.partition(files, file.is_tasks)
  let #(sources, files) = list.partition(files, file.is_sources)
  let #(filters, files) = list.partition(files, file.is_filters)
  let #(fields, _files) = list.partition(files, file.is_fields)

  let #(filters, model) = load_custom(filters, model, custom.Filters)
  let #(fields, model) = load_custom(fields, model, custom.Fields)
  let #(sources, model) = load_custom(sources, model, custom.Sources)

  let #(tasks, errors) =
    load_docs(tasks, props.decode(_, task.decoder(fields, sources, filters)))

  let tasks = dict.from_list(list.map(tasks, fn(task) { #(task.id, task) }))
  Model(tasks:, errors: list.append(model.errors, errors))
}

fn load_custom(
  files: List(File),
  model: Model,
  construct: fn(Dict(String, Custom)) -> custom,
) -> #(custom, Model) {
  let #(custom, errors) = load_docs(files, custom.decode)
  let errors = list.append(model.errors, errors)
  let custom = list.fold(custom, dict.new(), dict.merge)
  #(construct(custom), Model(..model, errors:))
}

fn load_docs(
  files: List(File),
  then: fn(Dynamic) -> Result(v, Report(Error)),
) -> #(List(v), List(Report(Error))) {
  result.partition({
    use file <- list.flat_map(files)
    use doc, index <- list.index_map(file.docs)

    then(doc)
    |> report.error_context(error.IndexContext(index))
    |> report.error_context(error.PathContext(file.path))
  })
}

fn load_files(config: Config, model: Model) -> #(List(File), Model) {
  let #(files, errors) =
    result.partition({
      use path <- list.map(path.wildcard(config.prefix, config.pattern))
      use <- extra.return(report.error_context(_, error.PathContext(path)))
      load_file(config.prefix, path)
    })

  #(files, Model(..model, errors:))
}

fn load_file(prefix: String, path: String) -> Result(File, Report(Error)) {
  use dynamic <- result.try(
    yaml.decode_file(filepath.join(prefix, path))
    |> report.map_error(error.YamlError),
  )

  use docs <- result.try(decoder.run(dynamic, decode.list(decode.dynamic)))

  case docs {
    [] -> report.error(error.EmptyFile)

    [header, ..docs] -> {
      let header = dots.split(header)
      use kind <- result.map(props.decode(header, file.kind_decoder()))
      File(kind:, path:, docs:)
    }
  }
}
