import filepath
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/pair
import gleam/result
import sb/extra
import sb/extra/dots
import sb/extra/report.{type Report}
import sb/extra/state
import sb/forms/access.{type Access}
import sb/forms/decoder
import sb/forms/dups.{type Dups}
import sb/forms/error.{type Error}
import sb/forms/props
import sb/forms/zero

pub type File {
  File(kind: Kind, path: String, docs: List(Dynamic))
}

pub type Document {
  Document(path: String, index: Int, data: Dynamic)
}

pub type Kind {
  CommandsV1
  FieldsV1
  FiltersV1
  SourcesV1
  TasksV1(category: List(String), runners: Access, approvers: Access)
}

pub fn is_tasks(file: File) -> Bool {
  case file {
    File(kind: TasksV1(..), ..) -> True
    _else -> False
  }
}

pub fn is_fields(file: File) -> Bool {
  case file {
    File(kind: FieldsV1, ..) -> True
    _else -> False
  }
}

pub fn is_filters(file: File) -> Bool {
  case file {
    File(kind: FiltersV1, ..) -> True
    _else -> False
  }
}

pub fn is_sources(file: File) -> Bool {
  case file {
    File(kind: SourcesV1, ..) -> True
    _else -> False
  }
}

pub fn decoder() {
  use kind <- props.get("kind", decoder.from(decode.string))

  case kind {
    "fields/v1" -> state.succeed(FieldsV1)
    "filters/v1" -> state.succeed(FiltersV1)
    "sources/v1" -> state.succeed(SourcesV1)
    "tasks/v1" -> tasks_v1_decoder()
    _bad -> state.fail(report.new(error.BadKind(kind)))
  }
}

fn tasks_v1_decoder() -> state.State(Kind, Report(Error), props.Context) {
  use category <- props.try("category", {
    zero.list(decoder.from(decode.list(decode.string)))
  })

  use runners <- props.try("runners", access.decoder())
  use approvers <- props.try("approvers", access.decoder())
  state.succeed(TasksV1(category:, runners:, approvers:))
}

pub fn load(
  prefix: String,
  path: String,
  loader: fn(String) -> a,
  then: fn(a) -> Result(Dynamic, Report(Error)),
) -> Result(File, Report(Error)) {
  use dynamic <- result.try(then(loader(filepath.join(prefix, path))))
  use docs <- result.try(decoder.run(dynamic, decode.list(decode.dynamic)))

  case docs {
    [] -> report.error(error.EmptyFile)

    [header, ..docs] -> {
      use <- extra.return(report.error_context(_, error.FileError))
      let header = dots.split(header)
      use kind <- result.map(props.decode(header, decoder()))
      File(kind:, path:, docs:)
    }
  }
}

pub fn load_documents(
  files: List(File),
  filter: fn(File) -> Bool,
) -> #(List(Document), List(File)) {
  use files <- pair.map_first(list.partition(files, filter))
  use file <- list.flat_map(files)
  use data, index <- list.index_map(file.docs)
  Document(path: file.path, index: index + 1, data:)
}

pub fn decode_documents(
  docs: List(Document),
  then: fn(Dups, Dynamic) -> Result(#(Dups, Result(v, _report)), _report),
) -> List(Result(v, _report)) {
  pair.second({
    use seen, doc <- list.map_fold(docs, dups.new())
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
