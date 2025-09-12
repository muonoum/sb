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
import sb/extra.{compose, return}
import sb/extra/dots
import sb/extra/path
import sb/extra/report.{type Report}
import sb/extra/state2.{type State} as state
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

type Dups {
  Dups(ids: Set(String), names: Set(#(String, List(String))))
}

fn dups() -> Dups {
  Dups(ids: set.new(), names: set.new())
}

fn check_id(
  dups: Dups,
  id: String,
  then: fn(Dups) -> #(Dups, Result(v, Report(Error))),
) -> #(Dups, Result(v, Report(Error))) {
  use <- bool.lazy_guard(set.contains(dups.ids, id), fn() {
    #(dups, report.error(error.DuplicateId(id)))
  })

  then(Dups(..dups, ids: set.insert(dups.ids, id)))
}

fn check_id2(
  id: String,
  data: v,
) -> State(Result(#(String, v), Report(Error)), Dups) {
  use dups: Dups <- state.with(state.get())

  use <- bool.guard(
    set.contains(dups.ids, id),
    state.return(report.error(error.DuplicateId(id))),
  )

  use <- state.do(state.put(Dups(..dups, ids: set.insert(dups.ids, id))))
  state.return(Ok(#(id, data)))
}

fn check_names(
  dups: Dups,
  name: String,
  category: List(String),
  then: fn(Dups) -> #(Dups, Result(v, Report(Error))),
) -> #(Dups, Result(v, Report(Error))) {
  use <- bool.lazy_guard(set.contains(dups.names, #(name, category)), fn() {
    #(dups, report.error(error.DuplicateNames(name, category)))
  })

  then(Dups(..dups, names: set.insert(dups.names, #(name, category))))
}

type Document {
  Document(path: String, index: Int, data: Dynamic)
}

fn load(_model: Model, config: Config) -> Model {
  use <- return(state.run(context: [], state: _))
  use files <- state.with(load_files(config.prefix, config.pattern))

  let #(tasks, files) = load_documents(files, file.is_tasks)
  let #(sources, files) = load_documents(files, file.is_sources)
  let #(fields, files) = load_documents(files, file.is_fields)
  let #(filters, _rest) = load_documents(files, file.is_filters)

  use sources <- state.with(load_custom(sources, custom.Sources))
  use fields <- state.with(load_custom(fields, custom.Fields))
  use filters <- state.with(load_custom(filters, custom.Filters))

  use tasks <- state.with(load_tasks(tasks, sources:, fields:, filters:))
  use errors <- state.with(state.get())
  state.return(Model(tasks: dict.from_list(tasks), errors:))
}

fn partition_results(
  results: List(Result(v, Report(Error))),
) -> State(List(v), List(Report(Error))) {
  use context <- state.with(state.get())
  let #(oks, errors) = result.partition(results)
  use <- state.do(state.put(list.append(context, errors)))
  state.return(oks)
}

fn load_files(
  prefix: String,
  pattern: String,
) -> State(List(File), List(Report(Error))) {
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
  use header, documents <- extra.non_empty_list(documents, Ok(file.empty(path)))
  use <- return(report.error_context(_, error.FileError))
  let header = dots.split(header)
  use kind <- result.map(props.decode(header, file.decoder()))
  let documents = list.map(documents, dots.split)
  File(kind:, path:, documents:)
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

fn load_custom(
  documents: List(Document),
  construct: fn(Dict(String, Custom)) -> custom,
) -> State(custom, List(Report(Error))) {
  use <- return(state.map(_, compose(dict.from_list, construct)))
  use <- return(partition_results)
  use <- return(state.run(context: dups(), state: _))
  use <- return(state.sequence)

  // let decoder = custom.decoder()
  // use dups, doc <- decode_documents(documents)
  // use #(id, custom) <- result.map(props.decode(doc, decoder))
  // use dups <- check_id(dups, id)
  // #(dups, Ok(#(id, custom)))

  use document <- list.map(documents)
  use <- return(state.map(_, error_context2(document)))
  case props.decode(document.data, custom.decoder()) {
    Error(report) -> state.return(Error(report))
    Ok(#(id, custom)) -> check_id2(id, custom)
  }
}

fn load_tasks(
  documents: List(Document),
  sources sources: custom.Sources,
  fields fields: custom.Fields,
  filters filters: custom.Filters,
) -> State(List(#(String, Task)), List(Report(Error))) {
  use <- return(partition_results)
  let decoder = task.decoder(filters:, fields:, sources:)
  use dups, doc <- decode_documents(documents)
  use task <- result.map(props.decode(doc, decoder))
  use dups <- check_names(dups, task.name, task.category)
  use dups <- check_id(dups, task.id)
  #(dups, Ok(#(task.id, task)))
}

fn decode_documents(
  documents: List(Document),
  then: fn(Dups, Dynamic) -> Result(#(Dups, Result(v, _report)), _report),
) -> List(Result(v, _report)) {
  pair.second({
    use dups, doc <- list.map_fold(documents, dups())
    use <- return(error_context(_, doc.path, doc.index))
    case then(dups, doc.data) {
      Error(report) -> #(dups, Error(report))
      Ok(#(dups, result)) -> #(dups, result)
    }
  })
}

fn error_context(
  pair: #(_, Result(v, Report(Error))),
  path: String,
  index: Int,
) -> #(_, Result(v, Report(Error))) {
  use result <- pair.map_second(pair)
  report.error_context(result, error.IndexContext(index))
  |> report.error_context(error.PathContext(path))
}

fn error_context2(
  document: Document,
) -> fn(Result(a, Report(Error))) -> Result(a, Report(Error)) {
  use result <- extra.identity
  report.error_context(result, error.IndexContext(document.index))
  |> report.error_context(error.PathContext(document.path))
}
