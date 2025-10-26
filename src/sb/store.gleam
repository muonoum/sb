import filepath
import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/otp/actor
import gleam/otp/supervision
import gleam/result
import gleam/set.{type Set}
import sb/extra/dots
import sb/extra/function.{compose, identity, return}
import sb/extra/list as list_extra
import sb/extra/pair as pair_extra
import sb/extra/report.{type Report}
import sb/extra/state.{type State}
import sb/extra_server/path
import sb/extra_server/yaml
import sb/forms/command.{type Command}
import sb/forms/custom.{type Custom}
import sb/forms/decoder
import sb/forms/error.{type Error}
import sb/forms/file.{type File, File}
import sb/forms/filter
import sb/forms/kind
import sb/forms/notifier.{type Notifier}
import sb/forms/props
import sb/forms/source
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
    reports: List(Report(Error)),
  )
}

pub opaque type Message {
  Schedule(store: Subject(Message))
  Load(store: Subject(Message))
  GetReports(subject: Subject(List(Report(Error))))
  GetTasks(subject: Subject(List(Task)))
  GetTask(subject: Subject(Result(Task, Nil)), id: String)
  GetNotifier(subject: Subject(Result(Notifier, Nil)), id: String)
  GetCommand(subject: Subject(Result(Command, Nil)), id: String)
}

pub fn get_tasks(store: Subject(Message)) -> List(Task) {
  process.call(store, call_timeout, GetTasks)
}

pub fn get_reports(store: Subject(Message)) -> List(Report(Error)) {
  process.call(store, call_timeout, GetReports)
}

pub fn get_task(
  store: Subject(Message),
  id: String,
) -> Result(Task, Report(Error)) {
  process.call(store, call_timeout, GetTask(_, id))
  |> report.replace_error(error.BadId(id))
}

pub fn get_notifier(
  store: Subject(Message),
  id: String,
) -> Result(Notifier, Report(Error)) {
  process.call(store, call_timeout, GetNotifier(_, id))
  |> report.replace_error(error.BadId(id))
}

pub fn get_command(
  store: Subject(Message),
  id: String,
) -> Result(Command, Report(Error)) {
  process.call(store, call_timeout, GetCommand(_, id))
  |> report.replace_error(error.BadId(id))
}

pub fn start(
  name: process.Name(Message),
  config: Config,
) -> Result(actor.Started(Subject(Message)), actor.StartError) {
  actor.new_with_initialiser(start_timeout, init)
  |> actor.named(name)
  |> actor.on_message(update(config))
  |> actor.start
}

pub fn supervised(
  name: process.Name(Message),
  config: Config,
) -> supervision.ChildSpecification(Subject(Message)) {
  supervision.ChildSpecification(
    start: fn() { start(name, config) },
    restart: supervision.Permanent,
    significant: False,
    child_type: supervision.Worker(shutdown_timeout),
  )
}

pub fn init(
  subject: Subject(Message),
) -> Result(actor.Initialised(Model, Message, Subject(Message)), String) {
  let model =
    Model(
      tasks: dict.new(),
      notifiers: dict.new(),
      commands: dict.new(),
      reports: [],
    )

  process.send(subject, Load(subject))
  Ok(actor.initialised(model) |> actor.returning(subject))
}

fn update(config: Config) -> fn(Model, Message) -> actor.Next(Model, Message) {
  use model, message <- identity

  case message {
    Schedule(store:) -> schedule(store, config, model)
    Load(store:) -> schedule(store, config, load(config))

    GetTasks(subject:) -> reply(subject, dict.values(model.tasks), model)
    GetReports(subject:) -> reply(subject, model.reports, model)
    GetTask(subject:, id:) -> reply(subject, dict.get(model.tasks, id), model)

    GetNotifier(subject:, id:) ->
      reply(subject, dict.get(model.notifiers, id), model)

    GetCommand(subject:, id:) ->
      reply(subject, dict.get(model.commands, id), model)
  }
}

fn reply(
  subject: Subject(v),
  value: v,
  model: Model,
) -> actor.Next(Model, Message) {
  process.send(subject, value)
  actor.continue(model)
}

fn schedule(
  store: Subject(Message),
  config: Config,
  model: Model,
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
  next: fn() -> State(Result(v, Report(Error)), Dups),
) -> State(Result(v, Report(Error)), Dups) {
  use dups: Dups <- state.bind(state.get())
  let error = state.return(report.error(error.DuplicateId(id)))
  use <- bool.guard(set.contains(dups.ids, id), error)
  let ids = set.insert(dups.ids, id)
  state.put(Dups(..dups, ids:)) |> state.do(next)
}

fn check_names(
  name: String,
  category: List(String),
  next: fn() -> State(Result(v, Report(Error)), Dups),
) -> State(Result(v, Report(Error)), Dups) {
  use dups: Dups <- state.bind(state.get())
  let error = state.return(report.error(error.DuplicateNames(name, category)))
  use <- bool.guard(set.contains(dups.names, #(name, category)), error)
  let names = set.insert(dups.names, #(name, category))
  state.put(Dups(..dups, names:)) |> state.do(next)
}

type Document {
  Document(path: String, index: Int, data: Dynamic)
}

fn document(path: String, index: Int, data: Dynamic) -> Document {
  Document(path:, index: index + 1, data:)
}

type TaskDocument {
  TaskDocument(document: Document, context: task.Context)
}

type Context {
  Context(files: List(File), reports: List(Report(Error)))
}

fn load(config: Config) -> Model {
  let context = Context(files: [], reports: [])
  state.run(load_model(config), context)
}

fn load_model(config: Config) -> State(Model, Context) {
  use <- state.do(load_files(config.prefix, config.pattern))

  use tasks <- state.bind(load_task_documents())

  use sources <- state.bind(load_documents(file.sources))
  use fields <- state.bind(load_documents(file.fields))
  use filters <- state.bind(load_documents(file.filters))
  use commands <- state.bind(load_documents(file.commands))
  use notifiers <- state.bind(load_documents(file.notifiers))

  use sources <- state.bind(load_custom(sources, source.builtin, custom.Sources))
  use fields <- state.bind(load_custom(fields, kind.builtin, custom.Fields))
  use filters <- state.bind(load_custom(filters, filter.builtin, custom.Filters))

  use commands <- state.bind(load_commands(commands))
  use notifiers <- state.bind(load_notifiers(notifiers))

  use tasks <- state.bind(
    load_tasks(tasks, sources:, fields:, filters:)
    |> state.map(dict.from_list),
  )

  use Context(reports:, ..) <- state.bind(state.get())
  let model = Model(tasks:, commands:, notifiers:, reports:)
  state.return(model)
}

fn get_file_kind(filter: fn(File) -> Result(v, Nil)) -> State(List(v), Context) {
  use Context(files:, ..) as context <- state.bind(state.get())
  let #(filtered, files) = list_extra.partition_map(files, filter)
  use <- state.do(state.put(Context(..context, files:)))
  state.return(filtered)
}

fn partition_results(
  results: List(Result(v, Report(Error))),
) -> State(List(v), Context) {
  use Context(reports:, ..) as context <- state.bind(state.get())
  let #(oks, errs) = result.partition(results)
  let reports = list.append(reports, errs)
  use <- state.do(state.put(Context(..context, reports:)))
  state.return(oks)
}

fn load_files(prefix: String, pattern: String) -> State(Nil, Context) {
  use _context <- state.update
  use <- return(compose(result.partition, pair_extra.map(_, Context)))
  use path <- list.map(path.wildcard(prefix, pattern))
  use <- return(report.error_context(_, error.PathContext(path)))
  load_file(prefix, path)
}

fn load_file(prefix: String, path: String) -> Result(File, Report(Error)) {
  use dynamic <- result.try(
    yaml.decode_file(filepath.join(prefix, path))
    |> report.map_error(error.YamlError),
  )

  case decoder.run(dynamic, decode.list(decode.dynamic)) {
    Error(report) -> Error(report)
    Ok([]) -> Ok(file.empty(path))

    Ok([header, ..documents]) -> {
      use <- return(report.error_context(_, error.BadFile))
      let header = dots.split(header)
      use kind <- result.try(props.decode(header, file.decoder()))
      let documents = list.map(documents, dots.split)
      Ok(File(kind:, path:, documents:))
    }
  }
}

fn load_documents(
  filter: fn(File) -> Result(File, Nil),
) -> State(List(Document), Context) {
  use files <- state.bind(get_file_kind(filter))
  use <- return(state.sequence)
  use file <- list.flat_map(files)
  use data, index <- list.index_map(file.documents)
  state.return(document(file.path, index, data))
}

fn load_task_documents() -> State(List(TaskDocument), Context) {
  use files <- state.bind(get_file_kind(file.tasks))
  use <- return(state.sequence)
  use #(path, documents, context) <- list.flat_map(files)
  use data, index <- list.index_map(documents)
  let document = document(path, index, data)
  state.return(TaskDocument(document:, context:))
}

fn load_custom(
  documents: List(Document),
  builtin: List(String),
  custom: fn(Dict(String, Custom)) -> custom,
) -> State(custom, Context) {
  use <- return(state.map(_, compose(dict.from_list, custom)))
  use <- return(partition_results)
  use <- return(state.run(_, context: dups()))
  use <- return(state.sequence)

  use document <- list.map(documents)
  use <- return(state.map(_, error_context(document)))
  case props.decode(document.data, custom.decoder(builtin)) {
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
) -> State(List(#(String, Task)), Context) {
  use <- return(partition_results)
  use <- return(state.run(_, context: dups()))
  use <- return(state.sequence)

  use TaskDocument(document:, context:) <- list.map(documents)
  use <- return(state.map(_, error_context(document)))
  let decoder = task.decoder(context:, sources:, fields:, filters:)

  case props.decode(document.data, decoder) {
    Error(report) -> state.return(Error(report))

    Ok(task) -> {
      use <- check_names(task.name, task.category)
      use <- check_id(task.id)
      state.return(Ok(#(task.id, task)))
    }
  }
}

fn load_notifiers(
  documents: List(Document),
) -> State(Dict(String, Notifier), Context) {
  use <- return(state.map(_, dict.from_list))
  use <- return(partition_results)
  use <- return(state.run(_, context: dups()))
  use <- return(state.sequence)

  use document <- list.map(documents)
  use <- return(state.map(_, error_context(document)))
  case props.decode(document.data, notifier.decoder()) {
    Error(report) -> state.return(Error(report))

    Ok(#(id, custom)) -> {
      use <- check_id(id)
      state.return(Ok(#(id, custom)))
    }
  }
}

fn load_commands(
  documents: List(Document),
) -> State(Dict(String, Command), Context) {
  use <- return(state.map(_, dict.from_list))
  use <- return(partition_results)
  use <- return(state.run(_, context: dups()))
  use <- return(state.sequence)

  use document <- list.map(documents)
  use <- return(state.map(_, error_context(document)))
  case props.decode(document.data, command.decoder()) {
    Error(report) -> state.return(Error(report))

    Ok(#(id, custom)) -> {
      use <- check_id(id)
      state.return(Ok(#(id, custom)))
    }
  }
}

fn error_context(
  document: Document,
) -> fn(Result(v, Report(Error))) -> Result(v, Report(Error)) {
  use result <- identity

  report.error_context(result, error.IndexContext(document.index))
  |> report.error_context(error.PathContext(document.path))
}
