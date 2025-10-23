import gleam/bool
import gleam/list
import gleam/order.{type Order}
import gleam/result
import gleam/string
import sb/extra/tree
import sb/extra/tree/zipper.{type Zipper}
import sb/extra/visibility.{type Visibility, Hidden, Visible}
import sb/forms/task.{type Task}

pub type Node {
  Root(Int)
  Category(Visibility, String)
  Task(Visibility, Task)
}

pub fn new(tasks: List(Task)) -> Zipper(Node) {
  let paths = {
    use task <- list.map(tasks)
    let categories = list.reverse(task.category)
    let initial = [Task(Visible, task)]
    use path, name <- list.fold(categories, initial)
    [Category(Visible, name), ..path]
  }

  let nodes = {
    use zipper, path <- list.fold(paths, zipper.new(tree.singleton(Root(0))))
    construct(zipper, path)
  }

  zipper.map_focus(nodes, tree.sort(_, compare))
}

fn construct(zipper: Zipper(Node), path: List(Node)) {
  case path {
    [] -> zipper.root(zipper)

    [node, ..rest] ->
      case find_child(zipper, node) {
        Ok(child) -> construct(child, rest)

        Error(Nil) ->
          tree.append_children(_, [tree.singleton(node)])
          |> zipper.map_focus(zipper, _)
          |> zipper.last_descendant
          |> construct(rest)
      }
  }
}

fn find_child(zipper: Zipper(Node), node: Node) -> Result(Zipper(Node), Nil) {
  use child <- result.try(zipper.first_child(zipper))
  test_child(child, node)
}

fn test_child(zipper: Zipper(Node), node: Node) -> Result(Zipper(Node), Nil) {
  let label = zipper.label(zipper)
  use <- bool.guard(equal(label, node), Ok(zipper))
  use sibling <- result.try(zipper.next_sibling(zipper))
  test_child(sibling, node)
}

fn compare(a: Node, b: Node) -> Order {
  case a, b {
    Root(..), _node -> order.Lt
    _node, Root(..) -> order.Gt
    Category(_, name1), Category(_, name2) -> string.compare(name1, name2)
    Category(..), Task(..) -> order.Gt
    Task(..), Category(..) -> order.Lt
    Task(_, task1), Task(_, task2) -> string.compare(task1.name, task2.name)
  }
}

fn equal(a: Node, b: Node) -> Bool {
  case a, b {
    Root(_count), Root(_count) -> True
    Task(_, task1), Task(_, task2) -> task1.id == task2.id
    Category(_, name1), Category(_, name2) -> name1 == name2
    _a, _b -> False
  }
}

pub fn count_visible_tasks(nodes: Zipper(Node)) -> Int {
  use node <- tree.count(zipper.tree(nodes))

  case node {
    Task(Visible, _task) -> True
    _else -> False
  }
}

pub fn count_visible_categories(nodes: Zipper(Node)) -> Int {
  use count, node <- list.fold(
    zipper.tree(nodes)
      |> tree.children
      |> list.map(tree.label),
    from: 0,
  )

  case node {
    Category(Visible, _name) -> count + 1
    _else -> count
  }
}

pub fn map(
  nodes: Zipper(Node),
  process: fn(Zipper(Node)) -> Zipper(Node),
) -> Zipper(Node) {
  let nodes = zipper.map_tree(nodes, show)
  let nodes = process(nodes)
  use label <- zipper.map_label(nodes)

  case label {
    Root(_count) -> Root(count_visible_categories(nodes))
    label -> label
  }
}

pub fn select(nodes: Zipper(Node), search: String) {
  let nodes = zipper.map_label(nodes, match(_, search))

  let nodes = case is_visible(zipper.label(nodes)) {
    True ->
      zipper.map_tree(nodes, show)
      |> select_next(search, zipper.next_tree)

    False -> select_next(nodes, search, zipper.next)
  }

  use label <- zipper.map_label(nodes)

  case label {
    Root(_count) -> Root(count_visible_categories(nodes))
    label -> label
  }
}

fn select_next(
  zipper: Zipper(Node),
  search: String,
  fun: fn(Zipper(Node)) -> Result(Zipper(Node), Nil),
) -> Zipper(Node) {
  case fun(zipper) {
    Error(Nil) -> zipper.root(zipper)
    Ok(zipper) -> select(zipper, search)
  }
}

fn show(node: Node) -> Node {
  case node {
    Root(count) -> Root(count)
    Task(_, task) -> Task(Visible, task)
    Category(_, name) -> Category(Visible, name)
  }
}

fn is_visible(node: Node) -> Bool {
  case node {
    Root(_count) -> False
    Task(Visible, _task) -> True
    Category(Visible, _name) -> True
    _node -> False
  }
}

fn match(node: Node, search: String) -> Node {
  let search = string.trim(search)

  case node {
    Root(count) -> Root(count)

    Task(_, task) if search == "" -> Task(Visible, task)
    Category(_, name) if search == "" -> Category(Visible, name)

    Task(Hidden, task) -> Task(Hidden, task)
    Category(Hidden, name) -> Category(Hidden, name)

    Task(_, task) ->
      case contains(task.name, search) {
        True -> Task(Visible, task)
        False -> Task(Hidden, task)
      }

    Category(_, name) ->
      case contains(name, search) {
        True -> Category(Visible, name)
        False -> Category(Hidden, name)
      }
  }
}

fn contains(check: String, search: String) -> Bool {
  string.contains(string.lowercase(check), string.lowercase(search))
}
