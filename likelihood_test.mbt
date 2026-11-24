///|
fn assert_likelihood(
  likelihood : @moonbayes.EvidenceLikelihood,
  expected_probability : Double,
  expected_log_probability : Double,
) -> Unit raise {
  assert_true((likelihood.probability() - expected_probability).abs() < 1.0e-12)
  assert_true(
    (likelihood.log_probability() - expected_log_probability).abs() < 1.0e-9,
  )
}

///|
test "evidence likelihood handles empty evidence" {
  let network = rain_umbrella_network()
  assert_likelihood(network.evidence_likelihood([]).unwrap(), 1.0, 0.0)
}

///|
test "evidence likelihood computes marginals and joint assignments" {
  let network = rain_umbrella_network()
  let umbrella_true = network.evidence_likelihood([("umbrella", 1)]).unwrap()
  assert_likelihood(umbrella_true, 0.24, @math.ln(0.24))
  let both_false = network
    .evidence_likelihood([("rain", 0), ("umbrella", 0)])
    .unwrap()
  assert_likelihood(both_false, 0.72, @math.ln(0.72))
}

///|
test "evidence likelihood eliminates hidden chain variables" {
  let network = chain_network()
  let c_false = network.evidence_likelihood([("c", 0)]).unwrap()
  assert_likelihood(c_false, 0.565, @math.ln(0.565))
}

///|
test "evidence likelihood keeps log probability when linear value underflows" {
  let nodes : Array[@moonbayes.NetworkNode] = []
  let evidence : Array[(String, Int32)] = []
  let mut index = 0
  while index < 20 {
    let name = "x" + index.to_string()
    let variable = @moonbayes.Variable::new(name, 2).unwrap()
    let factor = @moonbayes.Factor::new([variable], [1.0e-20, 1.0 - 1.0e-20]).unwrap()
    nodes.push(@moonbayes.NetworkNode::new(variable, [], factor).unwrap())
    evidence.push((name, 0))
    index += 1
  }
  let network = @moonbayes.BayesianNetwork::new(nodes).unwrap()
  let likelihood = network.evidence_likelihood(evidence).unwrap()
  assert_eq(likelihood.probability(), 0.0)
  assert_true(
    (likelihood.log_probability() - -400.0 * @math.ln(10.0)).abs() < 1.0e-9,
  )
}

///|
test "evidence likelihood reports impossible evidence" {
  let x = @moonbayes.Variable::new("x", 2).unwrap()
  let factor = @moonbayes.Factor::new([x], [1.0, 0.0]).unwrap()
  let node = @moonbayes.NetworkNode::new(x, [], factor).unwrap()
  let network = @moonbayes.BayesianNetwork::new([node]).unwrap()
  let likelihood = network.evidence_likelihood([("x", 1)]).unwrap()
  assert_eq(likelihood.probability(), 0.0)
  assert_true(likelihood.log_probability().is_inf())
  assert_true(likelihood.log_probability() < 0.0)
}

///|
test "evidence likelihood validates evidence" {
  let network = rain_umbrella_network()
  match network.evidence_likelihood([("missing", 0)]) {
    Err(UnknownVariable("missing")) => ()
    _ => assert_true(false)
  }
  match network.evidence_likelihood([("rain", 0), ("rain", 1)]) {
    Err(DuplicateEvidence("rain")) => ()
    _ => assert_true(false)
  }
  match network.evidence_likelihood([("rain", 2)]) {
    Err(EvidenceOutOfRange("rain", 2, 2)) => ()
    _ => assert_true(false)
  }
}
