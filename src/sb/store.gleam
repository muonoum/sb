import filepath
import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/list
import gleam/otp/actor
import gleam/otp/supervision
import gleam/pair
import gleam/result
import gleam/set.{type Set}
import sb/extra/dots
import sb/extra/function.{compose, identity, return}
import sb/extra/list as list_extra
import sb/extra/path
import sb/extra/report.{type Report}
import sb/extra/state.{type State}
import sb/extra/writer.{type Writer}
import sb/extra/yaml
import sb/forms/command.{type Command}
import sb/forms/custom.{type Custom}
import sb/forms/decoder
import sb/forms/error.{type Error}
import sb/forms/file.{type File, File}
import sb/forms/notifier.{type Notifier}
import sb/forms/props
import sb/forms/task.{type Task}

const start_timeout = 10_000

const call_timeout = 1000

const shutdown_timeout = 1000

pub type Config {
  Config(prefix: String, pattern: String, interval: Int)
}

pub opaque type Model {
  Model(
    tasks: Dict(String, Task),
    commands: Dict(String, Command),
    notifiers: Dict(String, Notifier),
    errors: List(Report(Error)),
  )
}

pub opaque type Message {
  Schedule(process.Subject(Message))
  Load(process.Subject(Message))
  GetErrors(process.Subject(List(Report(Error))))
  GetTasks(process.Subject(List(Task)))
  GetTask(process.Subject(Result(Task, Nil)), String)
  GetNotifier(process.Subject(Result(Notifier, Nil)), String)
  GetCommand(process.Subject(Result(Command, Nil)), String)
}

pub fn get_tasks(store: process.Subject(Message)) -> List(Task) {
  process.call(store, call_timeout, GetTasks)
}

pub fn get_errors(store: process.Subject(Message)) -> List(Report(Error)) {
  process.call(store, call_timeout, GetErrors)
}

pub fn get_task(
  store: process.Subject(Message),
  id: String,
) -> Result(Task, Report(Error)) {
  process.call(store, call_timeout, GetTask(_, id))
  |> report.replace_error(error.BadId(id))
}

pub fn get_notifier(
  store: process.Subject(Message),
  id: String,
) -> Result(Notifier, Report(Error)) {
  process.call(store, call_timeout, GetNotifier(_, id))
  |> report.replace_error(error.BadId(id))
}

pub fn get_comamnds(
  store: process.Subject(Message),
  id: String,
) -> Result(Command, Report(Error)) {
  process.call(store, call_timeout, GetCommand(_, id))
  |> report.replace_error(error.BadId(id))
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
  let model =
    Model(
      tasks: dict.new(),
      notifiers: dict.new(),
      commands: dict.new(),
      errors: [],
    )

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

      GetErrors(reply) -> {
        process.send(reply, model.errors)
        actor.continue(model)
      }

      GetTask(reply, id) -> {
        process.send(reply, dict.get(model.tasks, id))
        actor.continue(model)
      }

      GetNotifier(reply, id) -> {
        process.send(reply, dict.get(model.notifiers, id))
        actor.continue(model)
      }

      GetCommand(reply, id) -> {
        process.send(reply, dict.get(model.commands, id))
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

type Dups {
  Dups(ids: Set(String), names: Set(#(String, List(String))))
}

fn dups() -> Dups {
  Dups(ids: set.new(), names: set.new())
}

fn check_id(
  id: String,
  then: fn() -> State(Result(v, Report(Error)), Dups),
) -> State(Result(v, Report(Error)), Dups) {
  use dups: Dups <- state.bind(state.get())
  let error = state.return(report.error(error.DuplicateId(id)))
  use <- bool.guard(set.contains(dups.ids, id), error)
  let dups = Dups(..dups, ids: set.insert(dups.ids, id))
  state.do(state.put(dups), then)
}

fn check_names(
  name: String,
  category: List(String),
  then: fn() -> State(Result(v, Report(Error)), Dups),
) -> State(Result(v, Report(Error)), Dups) {
  use dups: Dups <- state.bind(state.get())
  let error = state.return(report.error(error.DuplicateNames(name, category)))
  use <- bool.guard(set.contains(dups.names, #(name, category)), error)
  let dups = Dups(..dups, names: set.insert(dups.names, #(name, category)))
  state.do(state.put(dups), then)
}

type Document {
  Document(path: String, index: Int, data: Dynamic)
}

type TaskDocument {
  TaskDocument(document: Document, defaults: task.Defaults)
}

fn load(model: Model, config: Config) -> Model {
  let #(model, errors) = writer.run(load_model(model, config))
  Model(..model, errors:)
}

fn load_model(model: Model, config: Config) -> Writer(Model, Report(Error)) {
  use files <- writer.bind(load_files(config.prefix, config.pattern))
  let #(tasks, files) = load_task_documents(files)

  let #(sources, files) = load_documents(files, file.is_sources)
  use sources <- writer.bind(load_custom(sources, custom.Sources))

  let #(fields, files) = load_documents(files, file.is_fields)
  use fields <- writer.bind(load_custom(fields, custom.Fields))

  let #(filters, files) = load_documents(files, file.is_filters)
  use filters <- writer.bind(load_custom(filters, custom.Filters))

  use tasks <- writer.bind(
    load_tasks(tasks, sources:, fields:, filters:)
    |> writer.map(dict.from_list),
  )

  let #(commands, files) = load_documents(files, file.is_commands)
  use commands <- writer.bind(load_commands(commands))

  let #(notifiers, _files) = load_documents(files, file.is_notifiers)
  use notifiers <- writer.bind(load_notifiers(notifiers))

  let model = Model(..model, tasks:, commands:, notifiers:)
  writer.return(model)
}

fn partition_results(
  results: List(Result(v, Report(Error))),
) -> Writer(List(v), Report(Error)) {
  let #(oks, errors) = result.partition(results)
  use <- writer.do(writer.put(errors))
  writer.return(oks)
}

fn load_files(
  prefix: String,
  pattern: String,
) -> Writer(List(File), Report(Error)) {
  use <- return(partition_results)
  use path <- list.map(path.wildcard(prefix, pattern))
  use <- return(report.error_context(_, error.PathContext(path)))
  load_file(prefix, path)
}

fn load_file(prefix: String, path: String) -> Result(File, Report(Error)) {
  use dynamic <- result.try(
    yaml.decode_file(filepath.join(prefix, path))
    |> report.map_error(error.YamlError),
  )

  use documents <- result.try(decoder.run(dynamic, decode.list(decode.dynamic)))

  case documents {
    [] -> Ok(file.empty(path))

    [header, ..documents] -> {
      use <- return(report.error_context(_, error.FileError))
      let header = dots.split(header)
      use kind <- result.try(props.decode(header, file.decoder()))
      let documents = list.map(documents, dots.split)
      Ok(File(kind:, path:, documents:))
    }
  }
}

fn load_documents(
  files: List(File),
  filter: fn(File) -> Bool,
) -> #(List(Document), List(File)) {
  use files <- pair.map_first(list.partition(files, filter))
  use file <- list.flat_map(files)
  use data, index <- list.index_map(file.documents)
  Document(path: file.path, index: index + 1, data:)
}

fn load_notifiers(
  _documents: List(Document),
) -> Writer(Dict(String, Notifier), Report(Error)) {
  writer.return(dict.new())
}

fn load_commands(
  _documents: List(Document),
) -> Writer(Dict(String, Command), Report(Error)) {
  writer.return(dict.new())
}

fn load_task_documents(files: List(File)) -> #(List(TaskDocument), List(File)) {
  use files <- pair.map_first(list_extra.partition_map(files, file.tasks))
  use #(path, documents, defaults) <- list.flat_map(files)
  use data, index <- list.index_map(documents)
  let document = Document(path:, index:, data:)
  TaskDocument(document:, defaults:)
}

fn load_custom(
  documents: List(Document),
  custom: fn(Dict(String, Custom)) -> custom,
) -> Writer(custom, Report(Error)) {
  use <- return(writer.map(_, compose(dict.from_list, custom)))
  use <- return(partition_results)
  use <- return(compose(state.sequence, state.run(_, context: dups())))

  use document <- list.map(documents)
  use <- return(state.map(_, error_context(document)))
  case props.decode(document.data, custom.decoder()) {
    Error(report) -> state.return(Error(report))

    Ok(#(id, custom)) -> {
      use <- check_id(id)
      state.return(Ok(#(id, custom)))
    }
  }
}

fn load_tasks(
  documents: List(TaskDocument),
  sources sources: custom.Sources,
  fields fields: custom.Fields,
  filters filters: custom.Filters,
) -> Writer(List(#(String, Task)), Report(Error)) {
  use <- return(partition_results)
  use <- return(compose(state.sequence, state.run(_, context: dups())))

  use TaskDocument(document:, defaults:) <- list.map(documents)
  use <- return(state.map(_, error_context(document)))
  let decoder = task.decoder(defaults:, sources:, fields:, filters:)
  case props.decode(document.data, decoder) {
    Error(report) -> state.return(Error(report))

    Ok(task) -> {
      use <- check_names(task.name, task.category)
      use <- check_id(task.id)
      state.return(Ok(#(task.id, task)))
    }
  }
}

fn error_context(
  document: Document,
) -> fn(Result(a, Report(Error))) -> Result(a, Report(Error)) {
  use result <- identity
  report.error_context(result, error.IndexContext(document.index))
  |> report.error_context(error.PathContext(document.path))
}
