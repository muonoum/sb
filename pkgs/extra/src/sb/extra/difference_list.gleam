import gleam/list
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
  let a = from_list([1, 2, 3])
  let b = from_list([4, 5, 6])
  let c = append(a, b)
  echo c
  echo to_list(c)
}
