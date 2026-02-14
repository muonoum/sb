import gleam/int
import gleam/list
import gleeunit/should
import sb/extra/diff_list
import sb/extra/function.{return}
import sb/extra_server

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
  use <- extra_server.log_duration("list")
  use list, i <- int.range(from: 0, to: count, with: [])
  list.append(list, [i])
}

fn time_diff_list(count: Int) -> List(Int) {
  use <- extra_server.log_duration("diff")
  use <- return(diff_list.to_list)
  use list, i <- int.range(from: 0, to: count, with: diff_list.new())
  diff_list.append(list, diff_list.from_list([i]))
}
