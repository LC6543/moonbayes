///|
fn assert_map_assignment(
  result : @moonbayes.MapAssignment,
  expected : Array[(String, Int32)],
) -> Unit raise {
  assert_eq(result.assignment(), expected)
}

///|
test "map finds marginal and joint modes" {
  let network = rain_umbrella_network()
  let rain_mode = network.map(["rain"], []).unwrap()
  assert_map_assignment(rain_mode, [("rain", 0)])
  assert_true((rain_mode.probability() - 0.8).abs() < 1.0e-12)
  assert_true((rain_mode.log_probability() - @math.ln(0.8)).abs() < 1.0e-12)
  let joint_mode = network.map(["rain", "umbrella"], []).unwrap()
  assert_map_assignment(joint_mode, [("rain", 0), ("umbrella", 0)])
  assert_true((joint_mode.probability() - 0.72).abs() < 1.0e-12)
}

///|
test "map conditions on evidence and preserves target order" {
  let network = rain_umbrella_network()
  let rain_mode = network.map(["rain"], [("umbrella", 1)]).unwrap()
  assert_map_assignment(rain_mode, [("rain", 1)])
  assert_true((rain_mode.probability() - 2.0 / 3.0).abs() < 1.0e-12)
  let reversed = network.map(["umbrella", "rain"], []).unwrap()
  assert_map_assignment(reversed, [("umbrella", 0), ("rain", 0)])
}

///|
test "map eliminates hidden chain variables" {
  let network = chain_network()
  let predicted = network.map(["c"], []).unwrap()
  assert_map_assignment(predicted, [("c", 0)])
  assert_true((predicted.probability() - 0.565).abs() < 1.0e-12)
  let conditioned = network.map(["a"], [("c", 0)]).unwrap()
  assert_map_assignment(conditioned, [("a", 0)])
  assert_true((conditioned.probability() - 0.335 / 0.565).abs() < 1.0e-12)
}

///|
test "map rejects impossible evidence" {
  let x = @moonbayes.Variable::new("x", 2).unwrap()
  let y = @moonbayes.Variable::new("y", 2).unwrap()
  let x_factor = @moonbayes.Factor::new([x], [1.0, 0.0]).unwrap()
  let y_factor = @moonbayes.Factor::new([y, x], [0.5, 0.5, 0.5, 0.5]).unwrap()
  let x_node = @moonbayes.NetworkNode::new(x, [], x_factor).unwrap()
  let y_node = @moonbayes.NetworkNode::new(y, ["x"], y_factor).unwrap()
  let network = @moonbayes.BayesianNetwork::new([x_node, y_node]).unwrap()
  match network.map(["y"], [("x", 1)]) {
    Err(FactorFailure(ZeroMass)) => ()
    _ => assert_true(false)
  }
}

///|
test "map validates targets and evidence" {
  let network = rain_umbrella_network()
  match network.map([], []) {
    Err(EmptyQuery) => ()
    _ => assert_true(false)
  }
  match network.map(["missing"], []) {
    Err(UnknownVariable("missing")) => ()
    _ => assert_true(false)
  }
  match network.map(["rain", "rain"], []) {
    Err(DuplicateTarget("rain")) => ()
    _ => assert_true(false)
  }
  match network.map(["rain"], [("rain", 0)]) {
    Err(TargetIsEvidence("rain")) => ()
    _ => assert_true(false)
  }
  match network.map(["rain"], [("umbrella", 2)]) {
    Err(EvidenceOutOfRange("umbrella", 2, 2)) => ()
    _ => assert_true(false)
  }
}
