///|
fn main {
  let rain = @moonbayes.Variable::new("rain", 2).unwrap()
  let umbrella = @moonbayes.Variable::new("umbrella", 2).unwrap()
  let prior = @moonbayes.Factor::new([rain], [0.8, 0.2]).unwrap()
  let likelihood = @moonbayes.Factor::new([rain, umbrella], [0.9, 0.1, 0.2, 0.8]).unwrap()
  let umbrella_cpt = @moonbayes.Factor::new([umbrella, rain], [
    0.9, 0.2, 0.1, 0.8,
  ]).unwrap()
  let joint = prior.multiply(likelihood).unwrap()
  let rain_node = @moonbayes.NetworkNode::new(rain, [], prior).unwrap()
  let umbrella_node = @moonbayes.NetworkNode::new(
    umbrella,
    ["rain"],
    umbrella_cpt,
  ).unwrap()
  let network = @moonbayes.BayesianNetwork::new([rain_node, umbrella_node]).unwrap()
  let umbrella_marginal = joint.marginalize(["umbrella"]).unwrap()
  let inferred_rain = network.query(["rain"], [("umbrella", 1)]).unwrap()
  let observed_rain = joint.restrict([("rain", 0)]).unwrap()
  let posterior = observed_rain.normalize().unwrap()
  println(
    "P(umbrella = false) = " +
    umbrella_marginal.value_at([0]).unwrap().to_string(),
  )
  println(
    "P(umbrella = true) = " +
    umbrella_marginal.value_at([1]).unwrap().to_string(),
  )
  println(
    "P(umbrella = true | rain = false) = " +
    posterior.value_at([1]).unwrap().to_string(),
  )
  let order = network.topological_order()
  println("Topological root = " + order[0])
  println("Topological child = " + order[1])
  println(
    "Inferred P(rain = true | umbrella = true) = " +
    inferred_rain.value_at([1]).unwrap().to_string(),
  )
}
