///|
/// A maximum a posteriori assignment over a requested target set.
pub struct MapAssignment {
  priv assignment : Array[(String, Int32)]
  priv probability : Double
  priv log_probability : Double
}

///|
/// Returns target assignments in the requested order.
pub fn MapAssignment::assignment(
  self : MapAssignment,
) -> Array[(String, Int32)] {
  self.assignment.copy()
}

///|
/// Returns the conditioned posterior probability of this assignment.
pub fn MapAssignment::probability(self : MapAssignment) -> Double {
  self.probability
}

///|
/// Returns the natural-log posterior probability of this assignment.
pub fn MapAssignment::log_probability(self : MapAssignment) -> Double {
  self.log_probability
}

///|
/// Finds a maximum a posteriori assignment over `targets`.
///
/// The target posterior is first computed exactly by summing hidden variables,
/// then the largest posterior entry is selected. When `targets` contains every
/// non-evidence variable, this returns the maximum a posteriori explanation
/// (MPE).
pub fn BayesianNetwork::map(
  self : BayesianNetwork,
  targets : Array[String],
  evidence : Array[(String, Int32)],
) -> Result[MapAssignment, InferenceError] {
  let posterior = match self.query(targets, evidence) {
    Ok(factor) => factor
    Err(error) => return Err(error)
  }
  let values = posterior.values()
  let mut best_index = 0
  let mut position = 1
  while position < values.length() {
    if values[position] > values[best_index] {
      best_index = position
    }
    position += 1
  }
  let best_assignment = match posterior.assignment_at(best_index) {
    Ok(assignment) => assignment
    Err(error) => return Err(FactorFailure(error))
  }
  let variables = posterior.scope()
  let assignment : Array[(String, Int32)] = []
  position = 0
  while position < variables.length() {
    assignment.push((variables[position].name(), best_assignment[position]))
    position += 1
  }
  let probability = values[best_index]
  Ok(MapAssignment::{
    assignment,
    probability,
    log_probability: @math.ln(probability),
  })
}
