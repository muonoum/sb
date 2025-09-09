import gleam/dict.{type Dict}
import gleam/erlang/process
import gleam/list
import gleam/otp/actor
import gleam/otp/supervision
import gleam/result
import sb/extra
import sb/extra/path
import sb/extra/report.{type Report}
import sb/extra/yaml
import sb/forms/custom
import sb/forms/dups
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

fn load(model: Model, config: Config) -> Model {
  let #(files, file_errors) =
    result.partition({
      use path <- list.map(path.wildcard(config.prefix, config.pattern))
      use <- extra.return(report.error_context(_, error.PathContext(path)))
      use result <- file.load(config.prefix, path, yaml.decode_file)
      report.map_error(result, error.YamlError)
    })

  let #(tasks, files) = file.load_documents(files, file.is_tasks)
  let #(sources, files) = file.load_documents(files, file.is_sources)
  let #(fields, files) = file.load_documents(files, file.is_fields)
  let #(filters, _rest) = file.load_documents(files, file.is_filters)

  let #(sources, source_errors) =
    result.partition({
      let decoder = custom.decoder()
      use seen, doc <- file.decode_documents(sources)
      use #(id, custom) <- result.map(props.decode(doc, decoder))
      use seen <- dups.id(seen, id)
      #(seen, Ok(#(id, custom)))
    })

  let #(fields, field_errors) =
    result.partition({
      let decoder = custom.decoder()
      use seen, doc <- file.decode_documents(fields)
      use #(id, custom) <- result.map(props.decode(doc, decoder))
      use seen <- dups.id(seen, id)
      #(seen, Ok(#(id, custom)))
    })

  let #(filters, filter_errors) =
    result.partition({
      let decoder = custom.decoder()
      use seen, doc <- file.decode_documents(filters)
      use #(id, custom) <- result.map(props.decode(doc, decoder))
      use seen <- dups.id(seen, id)
      #(seen, Ok(#(id, custom)))
    })

  let #(tasks, task_errors) =
    result.partition({
      let sources = custom.Sources(dict.from_list(sources))
      let fields = custom.Fields(dict.from_list(fields))
      let filters = custom.Filters(dict.from_list(filters))

      let decoder = task.decoder(fields, sources, filters)
      use seen, doc <- file.decode_documents(tasks)
      use task <- result.map(props.decode(doc, decoder))
      use seen <- dups.names(seen, task.name, task.category)
      use seen <- dups.id(seen, task.id)
      #(seen, Ok(#(task.id, task)))
    })

  let errors =
    model.errors
    |> list.append(file_errors)
    |> list.append(filter_errors)
    |> list.append(field_errors)
    |> list.append(source_errors)
    |> list.append(task_errors)

  Model(tasks: dict.from_list(tasks), errors:)
}
