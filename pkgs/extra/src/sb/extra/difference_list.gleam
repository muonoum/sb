import gleam/io
import gleam/list
import lap
import sb/extra/function.{compose}

// https://h2.jaguarpaw.co.uk/posts/demystifying-dlist/

pub type DList(v) {
  DList(run: fn(List(v)) -> List(v))
}

pub fn new() -> DList(v) {
  from_list([])
}

pub fn from_list(a: List(v)) -> DList(v) {
  use b <- DList
  list.append(a, b)
}

pub fn to_list(list: DList(v)) -> List(v) {
  list.run([])
}

pub fn append(a: DList(v), b: DList(v)) -> DList(v) {
  DList(compose(b.run, a.run))
}

pub fn main() {
  let count = 50_000
  let timing = lap.start_in_milliseconds("list")

  list.range(0, count)
  |> list.fold(from: [], with: fn(list, i) { list.append(list, [i]) })

  let timing = lap.time(timing, "dlist")

  list.range(0, count)
  |> list.fold(from: new(), with: fn(list, i) { append(list, from_list([i])) })
  |> to_list

  let timing = lap.time(timing, "end")

  io.println(lap.pretty_print(lap.sort_max(timing)))
}
