///|
fn assert_posterior_values(
  factor : @moonbayes.Factor,
  expected : Array[Double],
) -> Unit raise {
  let actual = factor.values()
  assert_eq(actual.length(), expected.length())
  let mut index = 0
  while index < expected.length() {
    assert_true((actual[index] - expected[index]).abs() < 1.0e-9)
    index += 1
  }
}

///|
fn rain_umbrella_network() -> @moonbayes.BayesianNetwork {
  let network = @moonbayes.BayesianNetwork::new([rain_node(), umbrella_node()]).unwrap()
  network
}

///|
fn chain_network() -> @moonbayes.BayesianNetwork {
  let a = @moonbayes.Variable::new("a", 2).unwrap()
  let b = @moonbayes.Variable::new("b", 2).unwrap()
  let c = @moonbayes.Variable::new("c", 2).unwrap()
  let a_factor = @moonbayes.Factor::new([a], [0.5, 0.5]).unwrap()
  let b_factor = @moonbayes.Factor::new([b, a], [0.9, 0.2, 0.1, 0.8]).unwrap()
  let c_factor = @moonbayes.Factor::new([c, b], [0.7, 0.4, 0.3, 0.6]).unwrap()
  let a_node = @moonbayes.NetworkNode::new(a, [], a_factor).unwrap()
  let b_node = @moonbayes.NetworkNode::new(b, ["a"], b_factor).unwrap()
  let c_node = @moonbayes.NetworkNode::new(c, ["b"], c_factor).unwrap()
  @moonbayes.BayesianNetwork::new([a_node, b_node, c_node]).unwrap()
}

///|
test "query computes marginal probabilities" {
  let network = rain_umbrella_network()
  let rain = network.query(["rain"], []).unwrap()
  assert_posterior_values(rain, [0.8, 0.2])
  let umbrella = network.query(["umbrella"], []).unwrap()
  assert_posterior_values(umbrella, [0.76, 0.24])
}

///|
test "query conditions on evidence" {
  let network = rain_umbrella_network()
  let rain_given_umbrella = network.query(["rain"], [("umbrella", 1)]).unwrap()
  assert_posterior_values(rain_given_umbrella, [1.0 / 3.0, 2.0 / 3.0])
  let umbrella_given_rain = network.query(["umbrella"], [("rain", 0)]).unwrap()
  assert_posterior_values(umbrella_given_rain, [0.9, 0.1])
}

///|
test "query preserves requested target order" {
  let network = rain_umbrella_network()
  let joint = network.query(["umbrella", "rain"], []).unwrap()
  assert_eq(joint.variable_names(), ["umbrella", "rain"])
  assert_posterior_values(joint, [0.72, 0.04, 0.08, 0.16])
}

///|
test "query performs variable elimination through a chain" {
  let network = chain_network()
  let c = network.query(["c"], []).unwrap()
  assert_posterior_values(c, [0.565, 0.435])
  let a_given_c = network.query(["a"], [("c", 0)]).unwrap()
  assert_posterior_values(a_given_c, [0.335 / 0.565, 0.23 / 0.565])
}

///|
test "query validates targets and evidence" {
  let network = rain_umbrella_network()
  match network.query([], []) {
    Err(EmptyQuery) => ()
    _ => assert_true(false)
  }
  match network.query(["missing"], []) {
    Err(UnknownVariable("missing")) => ()
    _ => assert_true(false)
  }
  match network.query(["rain", "rain"], []) {
    Err(DuplicateTarget("rain")) => ()
    _ => assert_true(false)
  }
  match network.query(["rain"], [("missing", 0)]) {
    Err(UnknownVariable("missing")) => ()
    _ => assert_true(false)
  }
  match network.query(["rain"], [("umbrella", 0), ("umbrella", 1)]) {
    Err(DuplicateEvidence("umbrella")) => ()
    _ => assert_true(false)
  }
  match network.query(["rain"], [("rain", 0)]) {
    Err(TargetIsEvidence("rain")) => ()
    _ => assert_true(false)
  }
  match network.query(["rain"], [("umbrella", 2)]) {
    Err(EvidenceOutOfRange("umbrella", 2, 2)) => ()
    _ => assert_true(false)
  }
}
