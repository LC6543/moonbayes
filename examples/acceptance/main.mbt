///|
fn close(left : Double, right : Double) -> Bool {
  (left - right).abs() < 1.0e-9
}

///|
fn main raise {
  let rain = @bayes.Variable::new("rain", 2).unwrap()
  let umbrella = @bayes.Variable::new("umbrella", 2).unwrap()
  let prior = @bayes.Factor::new([rain], [0.8, 0.2]).unwrap()
  let likelihood = @bayes.Factor::new([rain, umbrella], [0.9, 0.1, 0.2, 0.8]).unwrap()
  let umbrella_cpt = @bayes.Factor::new([umbrella, rain], [0.9, 0.2, 0.1, 0.8]).unwrap()
  let joint = prior.multiply(likelihood).unwrap()
  let marginal = joint.marginalize(["umbrella"]).unwrap()
  assert_true(close(marginal.value_at([0]).unwrap(), 0.76))
  assert_true(close(marginal.value_at([1]).unwrap(), 0.24))

  let rain_node = @bayes.NetworkNode::new(rain, [], prior).unwrap()
  let umbrella_node = @bayes.NetworkNode::new(umbrella, ["rain"], umbrella_cpt).unwrap()
  let network = @bayes.BayesianNetwork::new([rain_node, umbrella_node]).unwrap()
  assert_eq(network.topological_order(), ["rain", "umbrella"])

  let posterior = network.query(["rain"], [("umbrella", 1)]).unwrap()
  assert_true(close(posterior.value_at([0]).unwrap(), 1.0 / 3.0))
  assert_true(close(posterior.value_at([1]).unwrap(), 2.0 / 3.0))

  let evidence = network.evidence_likelihood([("umbrella", 1)]).unwrap()
  assert_true(close(evidence.probability(), 0.24))
  assert_true(close(evidence.log_probability(), @math.ln(0.24)))
  assert_false(network.is_d_separated(["rain"], ["umbrella"], []).unwrap())

  let map_result = network.map(["rain"], [("umbrella", 1)]).unwrap()
  assert_eq(map_result.assignment(), [("rain", 1)])
  assert_true(close(map_result.probability(), 2.0 / 3.0))

  let config = @bayes.SamplingConfig::new(4000, 20261126UL).unwrap()
  let sampled = network
    .sample_posterior(["rain"], [("umbrella", 1)], config)
    .unwrap()
  assert_true(
    (sampled.estimate().value_at([1]).unwrap() - 2.0 / 3.0).abs() < 0.03,
  )
  assert_true(sampled.effective_sample_size() > 0.0)

  let prior_samples = network.sample_prior(config).unwrap()
  assert_eq(prior_samples.sample_count(), 4000)

  let encoded = network.to_json_string()
  let restored = @bayes.BayesianNetwork::from_json_string(encoded).unwrap()
  assert_eq(restored.topological_order(), network.topological_order())
  assert_eq(restored.to_json(), network.to_json())

  let renamed = network.rename_variable("rain", "weather").unwrap()
  assert_eq(renamed.topological_order(), ["weather", "umbrella"])

  let data = [
    [("rain", 0), ("umbrella", 0)],
    [("rain", 0), ("umbrella", 0)],
    [("rain", 0), ("umbrella", 1)],
    [("rain", 1), ("umbrella", 1)],
  ]
  let fitted = network.fit_complete_data(data, 1.0).unwrap()
  assert_true(
    close(
      fitted.distribution_of("rain").unwrap().value_at([0]).unwrap(),
      4.0 / 6.0,
    ),
  )

  let plan = network.inference_plan(["rain"], []).unwrap()
  assert_eq(plan.elimination_order(), ["umbrella"])
  assert_eq(plan.bucket_count(), 1)
  assert_eq(plan.max_bucket_size(), 4)
  assert_eq(plan.result_entries(), 2)

  println("moonbayes end-to-end acceptance passed")
}
