import filepath
import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/list
import gleam/option
import gleam/otp/actor
import gleam/otp/supervision
import gleam/pair
import gleam/result
import gleam/set.{type Set}
import pprint
import sb/extra
import sb/extra/dots
import sb/extra/path
import sb/extra/report.{type Report}
import sb/extra/state2.{type State} as state
import sb/extra/yaml
import sb/forms/custom.{type Custom}
import sb/forms/decoder
import sb/forms/dups.{type Dups}
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

pub type Document {
  Document(path: String, index: Int, data: Dynamic)
}

pub type Context {
  Context(
    custom: Dict(file.Kind, List(#(String, Custom))),
    tasks: List(File),
    reports: List(Report(Error)),
  )
}

fn state_load_path(prefix: String, path: String) -> State(Nil, Context) {
  use context <- state.with(state.get())

  case load_file(prefix, path) {
    Error(report) -> {
      let report = report.context(report, error.PathContext(path))
      state.put(Context(..context, reports: [report, ..context.reports]))
    }

    Ok(File(kind: file.TasksV1(..), ..) as file) ->
      state.put(Context(..context, tasks: [file, ..context.tasks]))

    Ok(File(kind: file.CommandsV1, ..) as file)
    | Ok(File(kind: file.SourcesV1, ..) as file)
    | Ok(File(kind: file.FieldsV1, ..) as file)
    | Ok(File(kind: file.FiltersV1, ..) as file) -> {
      state_load_custom(file)
    }
  }
}

// TODO: Bruke ny state for dups?
fn state_load_custom(file: File) -> State(Nil, Context) {
  let state = state.return(Nil)
  use _state, data, index <- list.index_fold(file.documents, state)
  use context <- state.update()

  let result =
    props.decode(data, custom.decoder())
    |> report.error_context(error.IndexContext(index))
    |> report.error_context(error.PathContext(file.path))

  case result {
    Error(report) -> {
      Context(..context, reports: [report, ..context.reports])
    }

    Ok(custom) -> {
      Context(..context, custom: {
        use kind <- dict.upsert(context.custom, file.kind)

        option.map(kind, list.prepend(_, custom))
        |> option.unwrap([custom])
      })
    }
  }
}

fn state_validate() -> State(Nil, Context) {
  use context: Context <- state.update()

  let _results = {
    use _kind, custom <- dict.map_values(context.custom)
    validate_kind(custom)
  }

  context
}

fn validate_kind(
  custom: List(#(String, Custom)),
) -> List(Result(#(String, Custom), Report(Error))) {
  use <- extra.return(pair.second)
  use seen, #(id, custom) <- list.map_fold(custom, set.new())
  use <- check_duplicate(seen, id)
  Ok(#(id, custom))
}

fn check_duplicate(
  seen: Set(String),
  key: String,
  then: fn() -> Result(v, Report(Error)),
) -> #(Set(String), Result(v, Report(Error))) {
  let duplicate = set.contains(seen, key)
  use <- bool.guard(duplicate, #(seen, report.error(error.DuplicateId(key))))
  #(set.insert(seen, key), then())
}

fn state_load_tasks() -> State(List(_), Context) {
  use context: Context <- state.with(state.get())

  let sources =
    custom.Sources(dict.from_list(
      dict.get(context.custom, file.SourcesV1)
      |> result.unwrap([]),
    ))

  let fields =
    custom.Fields(dict.from_list(
      dict.get(context.custom, file.FieldsV1)
      |> result.unwrap([]),
    ))

  let filters =
    custom.Filters(dict.from_list(
      dict.get(context.custom, file.FiltersV1)
      |> result.unwrap([]),
    ))

  // TODO: Bruke ny state for dups?
  let #(tasks, reports) =
    result.partition({
      use file <- list.flat_map(context.tasks)
      use doc <- list.map(file.documents)
      props.decode(doc, task.decoder(fields, sources, filters))
    })

  use context <- state.with(state.get())

  use <- state.do(state.put(
    Context(..context, reports: list.append(context.reports, reports)),
  ))

  state.return({
    use task <- list.map(tasks)
    #(task.id, task)
  })
}

fn load(_model: Model, config: Config) -> Model {
  let state =
    state.step(
      context: Context(custom: dict.new(), tasks: [], reports: []),
      state: path.wildcard(config.prefix, config.pattern)
        |> list.map(state_load_path(config.prefix, _))
        |> state.sequence
        |> state.do(state_validate)
        |> state.do(state_load_tasks),
    )

  // pprint.debug(state.0)
  Model(tasks: dict.from_list(state.0), errors: { state.1 }.reports)
  // let #(files, file_errors) =
  //   result.partition({
  //     use path <- list.map(path.wildcard(config.prefix, config.pattern))
  //     use <- extra.return(report.error_context(_, error.PathContext(path)))
  //     load_file(config.prefix, path)
  //   })

  // let #(task_documents, files) = load_documents(files, file.is_tasks)
  // let #(source_documents, files) = load_documents(files, file.is_sources)
  // let #(field_documents, files) = load_documents(files, file.is_fields)
  // let #(filter_documents, _rest) = load_documents(files, file.is_filters)

  // let #(sources, source_errors) = load_custom(source_documents)
  // let #(fields, field_errors) = load_custom(field_documents)
  // let #(filters, filter_errors) = load_custom(filter_documents)

  // let #(tasks, task_errors) =
  //   load_tasks(
  //     task_documents,
  //     custom.Sources(dict.from_list(sources)),
  //     custom.Fields(dict.from_list(fields)),
  //     custom.Filters(dict.from_list(filters)),
  //   )

  // let errors =
  //   file_errors
  //   |> list.append(filter_errors)
  //   |> list.append(field_errors)
  //   |> list.append(source_errors)
  //   |> list.append(task_errors)

  // Model(tasks: dict.from_list(tasks), errors:)
}

fn load_file(prefix: String, path: String) -> Result(File, Report(Error)) {
  use dynamic <- result.try(
    yaml.decode_file(filepath.join(prefix, path))
    |> report.map_error(error.YamlError),
  )

  use documents <- result.try(decoder.run(dynamic, decode.list(decode.dynamic)))

  case documents {
    [] -> report.error(error.EmptyFile)

    [header, ..documents] -> {
      use <- extra.return(report.error_context(_, error.FileError))
      let header = dots.split(header)
      use kind <- result.map(props.decode(header, file.decoder()))
      let documents = list.map(documents, dots.split)
      File(kind:, path:, documents:)
    }
  }
}

fn load_custom(
  documents: List(Document),
) -> #(List(#(String, Custom)), List(Report(Error))) {
  result.partition({
    let decoder = custom.decoder()
    use seen, doc <- decode_documents(documents)
    use #(id, custom) <- result.map(props.decode(doc, decoder))
    use seen <- dups.id(seen, id)
    #(seen, Ok(#(id, custom)))
  })
}

fn load_tasks(
  documents: List(Document),
  sources: custom.Sources,
  fields: custom.Fields,
  filters: custom.Filters,
) -> #(List(#(String, Task)), List(Report(Error))) {
  result.partition({
    let decoder = task.decoder(fields, sources, filters)
    use seen, doc <- decode_documents(documents)
    use task <- result.map(props.decode(doc, decoder))
    use seen <- dups.names(seen, task.name, task.category)
    use seen <- dups.id(seen, task.id)
    #(seen, Ok(#(task.id, task)))
  })
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

fn decode_documents(
  documents: List(Document),
  then: fn(Dups, Dynamic) -> Result(#(Dups, Result(v, _report)), _report),
) -> List(Result(v, _report)) {
  pair.second({
    use seen, doc <- list.map_fold(documents, dups.new())
    use <- extra.return(error_context(_, doc.path, doc.index))

    case then(seen, doc.data) {
      Error(report) -> #(seen, Error(report))
      Ok(#(seen, result)) -> #(seen, result)
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
