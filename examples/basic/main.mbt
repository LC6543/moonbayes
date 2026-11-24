///|
fn main {
  let rain = @moonbayes.Variable::new("rain", 2).unwrap()
  let umbrella = @moonbayes.Variable::new("umbrella", 2).unwrap()
  let prior = @moonbayes.Factor::new([rain], [0.8, 0.2]).unwrap()
  let likelihood = @moonbayes.Factor::new([rain, umbrella], [0.9, 0.1, 0.2, 0.8]).unwrap()
  let joint = prior.multiply(likelihood).unwrap()
  let umbrella_marginal = joint.marginalize(["umbrella"]).unwrap()
  println(
    "P(umbrella = false) = " +
    umbrella_marginal.value_at([0]).unwrap().to_string(),
  )
  println(
    "P(umbrella = true) = " +
    umbrella_marginal.value_at([1]).unwrap().to_string(),
  )
}
