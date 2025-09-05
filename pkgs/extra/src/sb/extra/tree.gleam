import gleam/list
import gleam/order.{type Order}

pub opaque type Tree(v) {
  Tree(label: v, children: List(Tree(v)))
}

pub fn new(label: v, children: List(Tree(v))) -> Tree(v) {
  Tree(label, children)
}

pub fn singleton(label: v) {
  new(label, [])
}

pub fn label(tree: Tree(v)) -> v {
  tree.label
}

pub fn children(tree: Tree(v)) -> List(Tree(v)) {
  tree.children
}

pub fn map(tree: Tree(v), with: fn(v) -> v) -> Tree(v) {
  Tree(label: with(tree.label), children: {
    use tree <- list.map(tree.children)
    map(tree, with)
  })
}

pub fn map_label(tree: Tree(v), with: fn(v) -> v) -> Tree(v) {
  Tree(..tree, label: with(tree.label))
}

pub fn append_children(tree: Tree(v), children: List(Tree(v))) -> Tree(v) {
  Tree(..tree, children: list.append(tree.children, children))
}

pub fn sort(tree: Tree(v), sorter: fn(v, v) -> Order) -> Tree(v) {
  let children =
    list.sort(tree.children, fn(a, b) { sorter(a.label, b.label) })
    |> list.map(sort(_, sorter))

  Tree(..tree, children: children)
}

pub fn to_list(tree: Tree(v)) -> List(v) {
  [tree.label, ..list.flat_map(tree.children, to_list)]
}

pub fn count(tree: Tree(v), matching: fn(v) -> Bool) -> Int {
  let start = case matching(tree.label) {
    False -> 0
    True -> 1
  }

  use sum, child <- list.fold(tree.children, start)
  sum + count(child, matching)
}

pub fn flatten(tree: Tree(v)) -> List(v) {
  [tree.label, ..list.flat_map(tree.children, flatten)]
}
