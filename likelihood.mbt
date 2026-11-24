///|
/// The probability and log probability of a complete evidence assignment.
pub struct EvidenceLikelihood {
  priv probability : Double
  priv log_probability : Double
}

///|
/// Returns the linear evidence probability.
pub fn EvidenceLikelihood::probability(self : EvidenceLikelihood) -> Double {
  self.probability
}

///|
/// Returns the natural-log evidence probability.
pub fn EvidenceLikelihood::log_probability(self : EvidenceLikelihood) -> Double {
  self.log_probability
}

///|
priv enum ScalingOutcome {
  Valid(Factor, Double)
  Impossible
  Invalid(FactorError)
}

///|
/// Computes the exact likelihood of an evidence assignment.
///
/// Hidden variables are eliminated with the same deterministic minimum-fill
/// strategy used by posterior queries. Factors are rescaled after each
/// multiplication, so the logarithm remains stable when the linear probability
/// underflows. Impossible evidence returns probability zero and negative
/// infinity for the log probability.
pub fn BayesianNetwork::evidence_likelihood(
  self : BayesianNetwork,
  evidence : Array[(String, Int32)],
) -> Result[EvidenceLikelihood, InferenceError] {
  match validate_network_evidence(self, evidence) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  if evidence.length() == 0 {
    return Ok(EvidenceLikelihood::{ probability: 1.0, log_probability: 0.0, })
  }
  let mut log_scale = 0.0
  let mut factors : Array[Factor] = []
  for node in self.nodes {
    let distribution = node.distribution()
    let scope = distribution.variable_names()
    let local_evidence : Array[(String, Int32)] = []
    for entry in evidence {
      if contains_name(scope, entry.0) {
        local_evidence.push(entry)
      }
    }
    let restricted = match distribution.restrict(local_evidence) {
      Ok(factor) => factor
      Err(error) => return Err(FactorFailure(error))
    }
    match normalize_with_log_scale(restricted, log_scale) {
      Valid(factor, scale) => {
        factors.push(factor)
        log_scale = scale
      }
      Impossible => return Ok(impossible_likelihood())
      Invalid(error) => return Err(FactorFailure(error))
    }
  }
  let mut candidates : Array[String] = []
  let mut position = self.order.length() - 1
  while position >= 0 {
    let name = self.order[position]
    if !evidence_contains(evidence, name) {
      candidates.push(name)
    }
    position -= 1
  }
  while candidates.length() > 0 {
    let variable = choose_elimination_variable(factors, candidates)
    let selected : Array[Factor] = []
    let remaining : Array[Factor] = []
    for factor in factors {
      if factor_has_variable(factor, variable) {
        selected.push(factor)
      } else {
        remaining.push(factor)
      }
    }
    if selected.length() > 0 {
      let mut product = selected[0]
      let mut factor_index = 1
      while factor_index < selected.length() {
        product = match product.multiply(selected[factor_index]) {
          Ok(factor) => factor
          Err(error) => return Err(FactorFailure(error))
        }
        match normalize_with_log_scale(product, log_scale) {
          Valid(factor, scale) => {
            product = factor
            log_scale = scale
          }
          Impossible => return Ok(impossible_likelihood())
          Invalid(error) => return Err(FactorFailure(error))
        }
        factor_index += 1
      }
      let retained = names_without(product.variable_names(), variable)
      let message = match product.marginalize(retained) {
        Ok(factor) => factor
        Err(error) => return Err(FactorFailure(error))
      }
      match normalize_with_log_scale(message, log_scale) {
        Valid(factor, scale) => {
          remaining.push(factor)
          log_scale = scale
        }
        Impossible => return Ok(impossible_likelihood())
        Invalid(error) => return Err(FactorFailure(error))
      }
    }
    factors = remaining
    candidates = names_without(candidates, variable)
  }
  if factors.length() == 0 {
    return Ok(EvidenceLikelihood::{
      probability: 0.0,
      log_probability: @double.neg_infinity,
    })
  }
  let mut combined = factors[0]
  position = 1
  while position < factors.length() {
    combined = match combined.multiply(factors[position]) {
      Ok(factor) => factor
      Err(error) => return Err(FactorFailure(error))
    }
    match normalize_with_log_scale(combined, log_scale) {
      Valid(factor, scale) => {
        combined = factor
        log_scale = scale
      }
      Impossible => return Ok(impossible_likelihood())
      Invalid(error) => return Err(FactorFailure(error))
    }
    position += 1
  }
  if log_scale.is_nan() || log_scale == @double.infinity {
    return Err(FactorFailure(ZeroMass))
  }
  let mut probability = @math.exp(log_scale)
  if probability > 1.0 {
    probability = 1.0
  }
  Ok(EvidenceLikelihood::{ probability, log_probability: log_scale, })
}

///|
fn normalize_with_log_scale(
  factor : Factor,
  log_scale : Double,
) -> ScalingOutcome {
  let mass = factor.total()
  if mass == 0.0 {
    return Impossible
  }
  if mass < 0.0 || mass.is_nan() || mass.is_inf() {
    return Invalid(ZeroMass)
  }
  let normalized = match factor.normalize() {
    Ok(factor) => factor
    Err(error) => return Invalid(error)
  }
  Valid(normalized, log_scale + @math.ln(mass))
}

///|
fn impossible_likelihood() -> EvidenceLikelihood {
  EvidenceLikelihood::{
    probability: 0.0,
    log_probability: @double.neg_infinity,
  }
}
