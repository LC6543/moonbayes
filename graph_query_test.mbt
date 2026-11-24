///|
fn graph_root(name : String) -> @moonbayes.NetworkNode {
  let variable = @moonbayes.Variable::new(name, 2).unwrap()
  let factor = @moonbayes.Factor::new([variable], [0.5, 0.5]).unwrap()
  @moonbayes.NetworkNode::new(variable, [], factor).unwrap()
}

///|
fn graph_child(name : String, parent : String) -> @moonbayes.NetworkNode {
  let variable = @moonbayes.Variable::new(name, 2).unwrap()
  let parent_variable = @moonbayes.Variable::new(parent, 2).unwrap()
  let factor = @moonbayes.Factor::new([variable, parent_variable], [
    0.5, 0.5, 0.5, 0.5,
  ]).unwrap()
  @moonbayes.NetworkNode::new(variable, [parent], factor).unwrap()
}

///|
fn graph_collider(
  name : String,
  left_parent : String,
  right_parent : String,
) -> @moonbayes.NetworkNode {
  let variable = @moonbayes.Variable::new(name, 2).unwrap()
  let left = @moonbayes.Variable::new(left_parent, 2).unwrap()
  let right = @moonbayes.Variable::new(right_parent, 2).unwrap()
  let factor = @moonbayes.Factor::new([variable, left, right], [
    0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5,
  ]).unwrap()
  @moonbayes.NetworkNode::new(variable, [left_parent, right_parent], factor).unwrap()
}

///|
fn graph_chain_network() -> @moonbayes.BayesianNetwork {
  @moonbayes.BayesianNetwork::new([
    graph_root("a"),
    graph_child("b", "a"),
    graph_child("c", "b"),
  ]).unwrap()
}

///|
fn graph_fork_network() -> @moonbayes.BayesianNetwork {
  @moonbayes.BayesianNetwork::new([
    graph_root("b"),
    graph_child("a", "b"),
    graph_child("c", "b"),
  ]).unwrap()
}

///|
fn graph_collider_network() -> @moonbayes.BayesianNetwork {
  @moonbayes.BayesianNetwork::new([
    graph_root("a"),
    graph_root("c"),
    graph_collider("b", "a", "c"),
  ]).unwrap()
}

///|
fn graph_collider_descendant_network() -> @moonbayes.BayesianNetwork {
  @moonbayes.BayesianNetwork::new([
    graph_root("a"),
    graph_root("c"),
    graph_collider("b", "a", "c"),
    graph_child("d", "b"),
  ]).unwrap()
}

///|
test "ancestors and descendants are returned in topological order" {
  let network = graph_chain_network()
  assert_eq(network.ancestors_of("c").unwrap(), ["a", "b"])
  assert_eq(network.ancestors_of("a").unwrap(), [])
  assert_eq(network.descendants_of("a").unwrap(), ["b", "c"])
  assert_eq(network.descendants_of("c").unwrap(), [])
  match network.ancestors_of("missing") {
    None => ()
    Some(_) => assert_true(false)
  }
}

///|
test "d-separation handles chains and forks" {
  let chain = graph_chain_network()
  assert_false(chain.is_d_separated(["a"], ["c"], []).unwrap())
  assert_true(chain.is_d_separated(["a"], ["c"], ["b"]).unwrap())
  let fork = graph_fork_network()
  assert_false(fork.is_d_separated(["a"], ["c"], []).unwrap())
  assert_true(fork.is_d_separated(["a"], ["c"], ["b"]).unwrap())
}

///|
test "d-separation handles colliders and collider descendants" {
  let collider = graph_collider_network()
  assert_true(collider.is_d_separated(["a"], ["c"], []).unwrap())
  assert_false(collider.is_d_separated(["a"], ["c"], ["b"]).unwrap())
  let descendant = graph_collider_descendant_network()
  assert_false(descendant.is_d_separated(["a"], ["c"], ["d"]).unwrap())
}

///|
test "d-separation validates query sets" {
  let network = graph_chain_network()
  match network.is_d_separated([], ["c"], []) {
    Err(EmptySet) => ()
    _ => assert_true(false)
  }
  match network.is_d_separated(["missing"], ["c"], []) {
    Err(UnknownNode("missing")) => ()
    _ => assert_true(false)
  }
  match network.is_d_separated(["a", "a"], ["c"], []) {
    Err(DuplicateSetMember("a")) => ()
    _ => assert_true(false)
  }
  match network.is_d_separated(["a"], ["b"], ["a"]) {
    Err(OverlappingSets("a")) => ()
    _ => assert_true(false)
  }
}
