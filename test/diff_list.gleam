import gleam/list
import pocket_watch
import sb/extra/diff_list

pub fn main() {
  let count = 50_000

  let list = run_list(count)
  let diff_list = run_diff_list(count)
  assert list == diff_list

  Nil
}

fn run_list(count: Int) -> List(Int) {
  use <- pocket_watch.simple("list")

  list.range(0, count)
  |> list.fold(from: [], with: fn(list, i) { list.append(list, [i]) })
}

fn run_diff_list(count: Int) -> List(Int) {
  use <- pocket_watch.simple("diff-list")

  list.range(0, count)
  |> list.fold(from: diff_list.new(), with: fn(list, i) {
    diff_list.append(list, diff_list.from_list([i]))
  })
  |> diff_list.to_list
}
