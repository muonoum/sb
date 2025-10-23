import gleam/list
import gleeunit/should
import pocket_watch
import sb/extra/diff_list
import sb/extra/function.{return}

pub fn diff_list_test() {
  diff_list.from_list([])
  |> diff_list.append(diff_list.from_list([1, 2, 3]))
  |> diff_list.append(diff_list.from_list([4, 5, 6]))
  |> diff_list.to_list
  |> should.equal([1, 2, 3, 4, 5, 6])
}

pub fn main() {
  let count = 50_000
  let list = time_list(count)
  let diff_list = time_diff_list(count)
  assert list == diff_list
  Nil
}

fn time_list(count: Int) -> List(Int) {
  use <- pocket_watch.simple("list")
  use list, i <- list.fold(list.range(0, count), from: [])
  list.append(list, [i])
}

fn time_diff_list(count: Int) -> List(Int) {
  use <- pocket_watch.simple("diff-list")
  use <- return(diff_list.to_list)
  use list, i <- list.fold(list.range(0, count), from: diff_list.new())
  diff_list.append(list, diff_list.from_list([i]))
}
