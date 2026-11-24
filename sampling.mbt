///|
/// The maximum number of samples accepted by one approximate query.
pub const MAX_SAMPLES : Int32 = 1000000

///|
/// Errors produced by approximate inference.
pub enum SamplingFailure {
  InvalidSampleCount(Int32)
  SampleCountTooLarge(Int32)
  EmptyTargets
  UnknownVariable(String)
  DuplicateTarget(String)
  DuplicateEvidence(String)
  TargetIsEvidence(String)
  EvidenceOutOfRange(String, Int32, Int32)
  FactorFailure(FactorError)
  ZeroWeight
}

///|
/// Returns a human-readable explanation of a sampling error.
pub fn SamplingFailure::message(self : SamplingFailure) -> String {
  match self {
    InvalidSampleCount(count) =>
      "sample count must be positive, got " + count.to_string()
    SampleCountTooLarge(count) =>
      "sample count exceeds the limit of " +
      MAX_SAMPLES.to_string() +
      ": " +
      count.to_string()
    EmptyTargets => "sampling query must contain at least one target"
    UnknownVariable(name) => "variable does not exist in this network: " + name
    DuplicateTarget(name) => "target appears more than once: " + name
    DuplicateEvidence(name) => "evidence appears more than once: " + name
    TargetIsEvidence(name) => "target cannot also be evidence: " + name
    EvidenceOutOfRange(name, value, size) =>
      "evidence value " +
      value.to_string() +
      " for " +
      name +
      " is outside domain size " +
      size.to_string()
    FactorFailure(error) => error.message()
    ZeroWeight => "all likelihood weights were zero"
  }
}

///|
/// Deterministic settings for a likelihood-weighting run.
pub struct SamplingConfig {
  priv samples : Int32
  priv seed : UInt64
}

///|
/// Creates a validated sampling configuration.
pub fn SamplingConfig::new(
  samples : Int32,
  seed : UInt64,
) -> Result[SamplingConfig, SamplingFailure] {
  if samples <= 0 {
    return Err(InvalidSampleCount(samples))
  }
  if samples > MAX_SAMPLES {
    return Err(SampleCountTooLarge(samples))
  }
  Ok(SamplingConfig::{ samples, seed, })
}

///|
/// Returns the requested sample count.
pub fn SamplingConfig::samples(self : SamplingConfig) -> Int32 {
  self.samples
}

///|
/// Returns the deterministic seed.
pub fn SamplingConfig::seed(self : SamplingConfig) -> UInt64 {
  self.seed
}

///|
/// The posterior estimate and diagnostic statistics from approximate
/// inference.
pub struct WeightedPosterior {
  priv estimate : Factor
  priv effective_sample_size : Double
}

///|
/// Returns the normalized posterior estimate.
pub fn WeightedPosterior::estimate(self : WeightedPosterior) -> Factor {
  self.estimate
}

///|
/// Returns the Kish effective sample size.
pub fn WeightedPosterior::effective_sample_size(
  self : WeightedPosterior,
) -> Double {
  self.effective_sample_size
}

///|
/// Estimates a posterior with deterministic likelihood weighting.
///
/// Non-evidence variables are sampled in topological order. Evidence nodes
/// contribute likelihood weights, which are accumulated in log space before
/// log-sum-exp aggregation.
pub fn BayesianNetwork::sample_posterior(
  self : BayesianNetwork,
  targets : Array[String],
  evidence : Array[(String, Int32)],
  config : SamplingConfig,
) -> Result[WeightedPosterior, SamplingFailure] {
  if targets.length() == 0 {
    return Err(EmptyTargets)
  }
  let target_variables : Array[Variable] = []
  let target_positions : Array[Int32] = []
  let mut position = 0
  while position < targets.length() {
    let name = targets[position]
    let node = match find_network_node(self.nodes, name) {
      Some(node) => node
      None => return Err(UnknownVariable(name))
    }
    let mut previous = 0
    while previous < position {
      if targets[previous] == name {
        return Err(DuplicateTarget(name))
      }
      previous += 1
    }
    target_variables.push(node.variable())
    target_positions.push(find_name_position(self.order, name))
    position += 1
  }
  match validate_sampling_evidence(self, evidence, targets) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  let target_count = match factor_table_size(target_variables) {
    Ok(count) => count
    Err(error) => return Err(FactorFailure(error))
  }
  let rng = @random.Rand::chacha8(seed=seed_bytes(config.seed()))
  let log_weights : Array[Double] = []
  let sample_targets : Array[Int32] = []
  let mut sample = 0
  while sample < config.samples() {
    let assignment = Array::make(self.order.length(), 0)
    let mut log_weight = 0.0
    let mut valid = true
    position = 0
    while position < self.order.length() {
      let name = self.order[position]
      let node = match find_network_node(self.nodes, name) {
        Some(node) => node
        None => {
          valid = false
          break
        }
      }
      match finding_evidence_value(evidence, name) {
        Some(value) => {
          assignment[position] = value
          let probability = match
            node_probability(node, value, assignment, self.order) {
            Value(probability) => probability
            Failure(error) => return Err(error)
          }
          if probability <= 0.0 {
            valid = false
            break
          }
          log_weight += @math.ln(probability)
        }
        None => {
          let value = match
            sample_node_value(node, assignment, self.order, rng) {
            Value(value) => value
            Failure(error) => return Err(error)
          }
          assignment[position] = value
        }
      }
      position += 1
    }
    if valid {
      let target_assignment = Array::make(target_positions.length(), 0)
      let mut target_index = 0
      while target_index < target_positions.length() {
        target_assignment[target_index] = assignment[target_positions[target_index]]
        target_index += 1
      }
      log_weights.push(log_weight)
      sample_targets.push(
        assignment_to_index(target_variables, target_assignment),
      )
    }
    sample += 1
  }
  if log_weights.length() == 0 {
    return Err(ZeroWeight)
  }
  let mut maximum = log_weights[0]
  position = 1
  while position < log_weights.length() {
    if log_weights[position] > maximum {
      maximum = log_weights[position]
    }
    position += 1
  }
  let counts = Array::make(target_count, 0.0)
  let mut total_weight = 0.0
  let mut squared_weight = 0.0
  position = 0
  while position < log_weights.length() {
    let weight = @math.exp(log_weights[position] - maximum)
    total_weight += weight
    squared_weight += weight * weight
    counts[sample_targets[position]] += weight
    position += 1
  }
  let normalized = Array::make(target_count, 0.0)
  position = 0
  while position < counts.length() {
    normalized[position] = counts[position] / total_weight
    position += 1
  }
  let estimate = match Factor::new(target_variables, normalized) {
    Ok(factor) => factor
    Err(error) => return Err(FactorFailure(error))
  }
  let effective_sample_size = total_weight * total_weight / squared_weight
  Ok(WeightedPosterior::{ estimate, effective_sample_size, })
}

///|
priv enum NodeProbabilityOutcome {
  Value(Double)
  Failure(SamplingFailure)
}

///|
priv enum NodeValueOutcome {
  Value(Int32)
  Failure(SamplingFailure)
}

///|
fn validate_sampling_evidence(
  network : BayesianNetwork,
  evidence : Array[(String, Int32)],
  targets : Array[String],
) -> Result[Unit, SamplingFailure] {
  let mut position = 0
  while position < evidence.length() {
    let (name, value) = evidence[position]
    let node = match find_network_node(network.nodes, name) {
      Some(node) => node
      None => return Err(UnknownVariable(name))
    }
    let mut previous = 0
    while previous < position {
      if evidence[previous].0 == name {
        return Err(DuplicateEvidence(name))
      }
      previous += 1
    }
    let size = node.variable().size()
    if value < 0 || value >= size {
      return Err(EvidenceOutOfRange(name, value, size))
    }
    if contains_name(targets, name) {
      return Err(TargetIsEvidence(name))
    }
    position += 1
  }
  Ok(())
}

///|
fn finding_evidence_value(
  evidence : Array[(String, Int32)],
  name : String,
) -> Int32? {
  for entry in evidence {
    if entry.0 == name {
      return Some(entry.1)
    }
  }
  None
}

///|
fn node_probability(
  node : NetworkNode,
  child_value : Int32,
  assignment : Array[Int32],
  order : Array[String],
) -> NodeProbabilityOutcome {
  let parents = node.parents()
  let cpt_assignment = Array::make(parents.length() + 1, 0)
  cpt_assignment[0] = child_value
  let mut position = 0
  while position < parents.length() {
    let parent_position = find_name_position(order, parents[position])
    cpt_assignment[position + 1] = assignment[parent_position]
    position += 1
  }
  match node.distribution().value_at(cpt_assignment) {
    Ok(probability) => Value(probability)
    Err(error) => Failure(FactorFailure(error))
  }
}

///|
fn sample_node_value(
  node : NetworkNode,
  assignment : Array[Int32],
  order : Array[String],
  rng : @random.Rand,
) -> NodeValueOutcome {
  let child_size = node.variable().size()
  let draw = rng.double()
  let mut cumulative = 0.0
  let mut last_positive = 0
  let mut child_value = 0
  while child_value < child_size {
    let probability = match
      node_probability(node, child_value, assignment, order) {
      Value(probability) => probability
      Failure(error) => return Failure(error)
    }
    if probability > 0.0 {
      last_positive = child_value
    }
    cumulative += probability
    if draw < cumulative {
      return Value(child_value)
    }
    child_value += 1
  }
  Value(last_positive)
}

///|
fn seed_bytes(seed : UInt64) -> Bytes {
  Bytes::makei(32, index => ((seed >> (index % 8 * 8)) & 255UL).to_byte())
}
