///|
fn rain_node() -> @moonbayes.NetworkNode {
  let rain = @moonbayes.Variable::new("rain", 2).unwrap()
  let factor = @moonbayes.Factor::new([rain], [0.8, 0.2]).unwrap()
  @moonbayes.NetworkNode::new(rain, [], factor).unwrap()
}

///|
fn umbrella_node() -> @moonbayes.NetworkNode {
  let rain = @moonbayes.Variable::new("rain", 2).unwrap()
  let umbrella = @moonbayes.Variable::new("umbrella", 2).unwrap()
  let factor = @moonbayes.Factor::new([umbrella, rain], [0.9, 0.2, 0.1, 0.8]).unwrap()
  @moonbayes.NetworkNode::new(umbrella, ["rain"], factor).unwrap()
}

///|
test "network node validates root and conditional tables" {
  let root = rain_node()
  assert_eq(root.variable_name(), "rain")
  assert_eq(root.parents(), [])
  let conditional = umbrella_node()
  assert_eq(conditional.variable_name(), "umbrella")
  assert_eq(conditional.parents(), ["rain"])
  assert_eq(conditional.distribution().variable_names(), ["umbrella", "rain"])
}

///|
test "network node rejects duplicate and self parents" {
  let x = @moonbayes.Variable::new("x", 2).unwrap()
  let y = @moonbayes.Variable::new("y", 2).unwrap()
  let factor = @moonbayes.Factor::new([y, x], [0.5, 0.5, 0.5, 0.5]).unwrap()
  match @moonbayes.NetworkNode::new(y, ["x", "x"], factor) {
    Err(DuplicateParent("x")) => ()
    _ => assert_true(false)
  }
  match @moonbayes.NetworkNode::new(y, ["y"], factor) {
    Err(SelfParent("y")) => ()
    _ => assert_true(false)
  }
}

///|
test "network node rejects malformed distribution scopes" {
  let rain = @moonbayes.Variable::new("rain", 2).unwrap()
  let umbrella = @moonbayes.Variable::new("umbrella", 2).unwrap()
  let missing_parent = @moonbayes.Factor::new([umbrella], [0.5, 0.5]).unwrap()
  match @moonbayes.NetworkNode::new(umbrella, ["rain"], missing_parent) {
    Err(DistributionScopeMismatch("umbrella")) => ()
    _ => assert_true(false)
  }
  let wrong_order = @moonbayes.Factor::new([rain, umbrella], [
    0.9, 0.1, 0.2, 0.8,
  ]).unwrap()
  match @moonbayes.NetworkNode::new(umbrella, ["rain"], wrong_order) {
    Err(DistributionScopeMismatch("umbrella")) => ()
    _ => assert_true(false)
  }
}

///|
test "network node rejects unnormalized conditional tables" {
  let x = @moonbayes.Variable::new("x", 2).unwrap()
  let factor = @moonbayes.Factor::new([x], [0.8, 0.4]).unwrap()
  match @moonbayes.NetworkNode::new(x, [], factor) {
    Err(UnnormalizedConditional("x", mass)) =>
      assert_true((mass - 1.2).abs() < 1.0e-12)
    _ => assert_true(false)
  }
}

///|
test "network node rejects child domain mismatch" {
  let umbrella = @moonbayes.Variable::new("umbrella", 2).unwrap()
  let wrong_child = @moonbayes.Variable::new("umbrella", 3).unwrap()
  let factor = @moonbayes.Factor::new([wrong_child], [0.3, 0.3, 0.4]).unwrap()
  match @moonbayes.NetworkNode::new(umbrella, [], factor) {
    Err(DistributionChildDomainMismatch("umbrella", 2, 3)) => ()
    _ => assert_true(false)
  }
}

///|
test "network builds deterministic topological order" {
  let network = @moonbayes.BayesianNetwork::new([umbrella_node(), rain_node()]).unwrap()
  assert_eq(network.node_count(), 2)
  assert_eq(network.topological_order(), ["rain", "umbrella"])
  assert_eq(network.parents_of("umbrella").unwrap(), ["rain"])
  assert_eq(network.parents_of("rain").unwrap(), [])
  assert_eq(network.node("rain").unwrap().variable_name(), "rain")
  assert_eq(network.distribution_of("umbrella").unwrap().variable_names(), [
    "umbrella", "rain",
  ])
}

///|
test "network rejects an empty network" {
  match @moonbayes.BayesianNetwork::new([]) {
    Err(EmptyNetwork) => ()
    _ => assert_true(false)
  }
}

///|
test "network rejects duplicate nodes" {
  match @moonbayes.BayesianNetwork::new([rain_node(), rain_node()]) {
    Err(DuplicateNode("rain")) => ()
    _ => assert_true(false)
  }
}

///|
test "network rejects unknown parents" {
  let umbrella = @moonbayes.Variable::new("umbrella", 2).unwrap()
  let cloud = @moonbayes.Variable::new("cloud", 2).unwrap()
  let factor = @moonbayes.Factor::new([umbrella, cloud], [0.9, 0.2, 0.1, 0.8]).unwrap()
  let node = @moonbayes.NetworkNode::new(umbrella, ["cloud"], factor).unwrap()
  match @moonbayes.BayesianNetwork::new([node]) {
    Err(UnknownParent("cloud")) => ()
    _ => assert_true(false)
  }
}

///|
test "network rejects parent domain mismatch" {
  let rain = @moonbayes.Variable::new("rain", 2).unwrap()
  let umbrella = @moonbayes.Variable::new("umbrella", 2).unwrap()
  let rain_with_wrong_domain = @moonbayes.Variable::new("rain", 3).unwrap()
  let root = @moonbayes.Factor::new([rain], [0.5, 0.5]).unwrap()
  let rain_node = @moonbayes.NetworkNode::new(rain, [], root).unwrap()
  let cpt = @moonbayes.Factor::new([umbrella, rain_with_wrong_domain], [
    0.5, 0.5, 0.5, 0.5, 0.5, 0.5,
  ]).unwrap()
  let umbrella_node = @moonbayes.NetworkNode::new(umbrella, ["rain"], cpt).unwrap()
  match @moonbayes.BayesianNetwork::new([rain_node, umbrella_node]) {
    Err(DistributionParentDomainMismatch("umbrella", "rain", 2, 3)) => ()
    _ => assert_true(false)
  }
}

///|
test "network rejects directed cycles" {
  let a = @moonbayes.Variable::new("a", 2).unwrap()
  let b = @moonbayes.Variable::new("b", 2).unwrap()
  let a_factor = @moonbayes.Factor::new([a, b], [0.9, 0.2, 0.1, 0.8]).unwrap()
  let b_factor = @moonbayes.Factor::new([b, a], [0.8, 0.1, 0.2, 0.9]).unwrap()
  let a_node = @moonbayes.NetworkNode::new(a, ["b"], a_factor).unwrap()
  let b_node = @moonbayes.NetworkNode::new(b, ["a"], b_factor).unwrap()
  match @moonbayes.BayesianNetwork::new([a_node, b_node]) {
    Err(CycleDetected) => ()
    _ => assert_true(false)
  }
}
