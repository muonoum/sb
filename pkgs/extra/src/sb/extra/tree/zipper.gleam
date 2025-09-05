import gleam/list
import gleam/result
import sb/extra/tree.{type Tree}

pub opaque type Zipper(v) {
  Zipper(
    focus: Tree(v),
    before: List(Tree(v)),
    after: List(Tree(v)),
    crumbs: List(Crumb(v)),
  )
}

pub opaque type Crumb(v) {
  Crumb(label: v, before: List(Tree(v)), after: List(Tree(v)))
}

pub fn new(tree: Tree(v)) -> Zipper(v) {
  Zipper(focus: tree, before: [], after: [], crumbs: [])
}

pub fn focus(zipper: Zipper(v)) -> Tree(v) {
  zipper.focus
}

pub fn label(zipper: Zipper(v)) -> v {
  tree.label(zipper.focus)
}

pub fn tree(zipper: Zipper(v)) -> Tree(v) {
  focus(root(zipper))
}

pub fn map_focus(zipper: Zipper(v), with: fn(Tree(v)) -> Tree(v)) -> Zipper(v) {
  Zipper(..zipper, focus: with(zipper.focus))
}

pub fn map_label(zipper: Zipper(v), with: fn(v) -> v) -> Zipper(v) {
  map_focus(zipper, tree.map_label(_, with))
}

pub fn map_tree(zipper: Zipper(v), with: fn(v) -> v) -> Zipper(v) {
  let crumbs = {
    use crumb <- list.map(zipper.crumbs)
    Crumb(..crumb, label: with(crumb.label))
  }

  Zipper(..zipper, crumbs: crumbs)
  |> map_focus(tree.map(_, with))
}

pub fn parent(zipper: Zipper(v)) -> Result(Zipper(v), Nil) {
  case zipper.crumbs {
    [] -> Error(Nil)

    [crumb, ..crumbs] -> {
      let children =
        list.append(list.reverse(zipper.before), [zipper.focus, ..zipper.after])

      let focus = tree.new(crumb.label, children)

      let zipper =
        Zipper(
          focus: focus,
          before: crumb.before,
          after: crumb.after,
          crumbs: crumbs,
        )

      Ok(zipper)
    }
  }
}

pub fn root(zipper: Zipper(v)) -> Zipper(v) {
  case parent(zipper) {
    Error(Nil) -> first_sibling(zipper)
    Ok(zipper) -> root(zipper)
  }
}

pub fn next(zipper: Zipper(v)) -> Result(Zipper(v), Nil) {
  result.or(first_child(zipper), next_sibling(zipper))
  |> result.or(next_ancestor_sibling(zipper))
}

pub fn next_tree(zipper: Zipper(v)) -> Result(Zipper(v), Nil) {
  result.or(next_sibling(zipper), next_ancestor_sibling(zipper))
}

pub fn first_child(zipper: Zipper(v)) -> Result(Zipper(v), Nil) {
  case tree.children(zipper.focus) {
    [] -> Error(Nil)

    [node, ..nodes] -> {
      let crumb =
        Crumb(
          label: tree.label(zipper.focus),
          before: zipper.before,
          after: zipper.after,
        )

      let crumbs = [crumb, ..zipper.crumbs]
      Ok(Zipper(focus: node, before: [], after: nodes, crumbs: crumbs))
    }
  }
}

pub fn last_child(zipper: Zipper(v)) -> Result(Zipper(v), Nil) {
  case list.reverse(tree.children(zipper.focus)) {
    [] -> Error(Nil)

    [node, ..nodes] -> {
      let label = tree.label(zipper.focus)

      let crumb =
        Crumb(label: label, before: zipper.before, after: zipper.after)

      let crumbs = [crumb, ..zipper.crumbs]
      let zipper = Zipper(focus: node, before: nodes, after: [], crumbs: crumbs)
      Ok(zipper)
    }
  }
}

pub fn first_sibling(zipper: Zipper(v)) -> Zipper(v) {
  case previous_sibling(zipper) {
    Error(Nil) -> zipper
    Ok(zipper) -> first_sibling(zipper)
  }
}

pub fn next_sibling(zipper: Zipper(v)) -> Result(Zipper(v), Nil) {
  case zipper.after {
    [] -> Error(Nil)

    [node, ..nodes] -> {
      let zipper =
        Zipper(
          focus: node,
          before: [zipper.focus, ..zipper.before],
          after: nodes,
          crumbs: zipper.crumbs,
        )

      Ok(zipper)
    }
  }
}

pub fn previous_sibling(zipper: Zipper(v)) -> Result(Zipper(v), Nil) {
  case zipper.before {
    [] -> Error(Nil)

    [node, ..nodes] -> {
      let zipper =
        Zipper(
          focus: node,
          before: nodes,
          after: [zipper.focus, ..zipper.after],
          crumbs: zipper.crumbs,
        )

      Ok(zipper)
    }
  }
}

pub fn next_ancestor_sibling(zipper: Zipper(v)) -> Result(Zipper(v), Nil) {
  case parent(zipper) {
    Error(Nil) -> Error(Nil)
    Ok(zipper) -> result.or(next_sibling(zipper), next_ancestor_sibling(zipper))
  }
}

pub fn last_descendant(zipper: Zipper(v)) -> Zipper(v) {
  case last_child(zipper) {
    Error(Nil) -> zipper
    Ok(zipper) -> last_descendant(zipper)
  }
}
