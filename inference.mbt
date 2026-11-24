///|
/// Errors produced while running exact inference.
pub enum InferenceError {
  EmptyQuery
  UnknownVariable(String)
  DuplicateTarget(String)
  DuplicateEvidence(String)
  TargetIsEvidence(String)
  EvidenceOutOfRange(String, Int32, Int32)
  FactorFailure(FactorError)
}

///|
/// Returns a human-readable explanation of an inference error.
pub fn InferenceError::message(self : InferenceError) -> String {
  match self {
    EmptyQuery => "query must contain at least one target variable"
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
  }
}

///|
/// Computes the exact posterior over `targets` conditioned on `evidence`.
///
/// Variables are eliminated with a deterministic minimum-fill heuristic. The
/// returned factor has exactly the requested target order and is normalized.
pub fn BayesianNetwork::query(
  self : BayesianNetwork,
  targets : Array[String],
  evidence : Array[(String, Int32)],
) -> Result[Factor, InferenceError] {
  if targets.length() == 0 {
    return Err(EmptyQuery)
  }
  let mut position = 0
  while position < targets.length() {
    let target = targets[position]
    if find_network_node(self.nodes, target) is None {
      return Err(UnknownVariable(target))
    }
    let mut previous = 0
    while previous < position {
      if targets[previous] == target {
        return Err(DuplicateTarget(target))
      }
      previous += 1
    }
    position += 1
  }
  position = 0
  while position < evidence.length() {
    let (name, value) = evidence[position]
    let node = match find_network_node(self.nodes, name) {
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
    factors.push(restricted)
  }
  let mut candidates : Array[String] = []
  position = self.order.length() - 1
  while position >= 0 {
    let name = self.order[position]
    if !contains_name(targets, name) && !evidence_contains(evidence, name) {
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
        factor_index += 1
      }
      let retained = names_without(product.variable_names(), variable)
      let message = match product.marginalize(retained) {
        Ok(factor) => factor
        Err(error) => return Err(FactorFailure(error))
      }
      remaining.push(message)
    }
    factors = remaining
    candidates = names_without(candidates, variable)
  }
  if factors.length() == 0 {
    return Err(EmptyQuery)
  }
  let mut posterior = factors[0]
  position = 1
  while position < factors.length() {
    posterior = match posterior.multiply(factors[position]) {
      Ok(factor) => factor
      Err(error) => return Err(FactorFailure(error))
    }
    position += 1
  }
  let ordered = match posterior.marginalize(targets) {
    Ok(factor) => factor
    Err(error) => return Err(FactorFailure(error))
  }
  match ordered.normalize() {
    Ok(factor) => Ok(factor)
    Err(error) => Err(FactorFailure(error))
  }
}

///|
fn evidence_contains(evidence : Array[(String, Int32)], name : String) -> Bool {
  for entry in evidence {
    if entry.0 == name {
      return true
    }
  }
  false
}

///|
fn factor_has_variable(factor : Factor, name : String) -> Bool {
  contains_name(factor.variable_names(), name)
}

///|
fn names_without(names : Array[String], removed : String) -> Array[String] {
  let result : Array[String] = []
  for name in names {
    if name != removed {
      result.push(name)
    }
  }
  result
}

///|
fn choose_elimination_variable(
  factors : Array[Factor],
  candidates : Array[String],
) -> String {
  let mut best = candidates[0]
  let mut best_fill = fill_edges(factors, best)
  let mut position = 1
  while position < candidates.length() {
    let candidate = candidates[position]
    let fill = fill_edges(factors, candidate)
    if fill < best_fill {
      best = candidate
      best_fill = fill
    }
    position += 1
  }
  best
}

///|
fn fill_edges(factors : Array[Factor], variable : String) -> Int32 {
  let neighbors = variable_neighbors(factors, variable)
  let mut fill = 0
  let mut left = 0
  while left < neighbors.length() {
    let mut right = left + 1
    while right < neighbors.length() {
      if !factors_connect(factors, neighbors[left], neighbors[right]) {
        fill += 1
      }
      right += 1
    }
    left += 1
  }
  fill
}

///|
fn variable_neighbors(
  factors : Array[Factor],
  variable : String,
) -> Array[String] {
  let neighbors : Array[String] = []
  for factor in factors {
    let names = factor.variable_names()
    if contains_name(names, variable) {
      for name in names {
        if name != variable && !contains_name(neighbors, name) {
          neighbors.push(name)
        }
      }
    }
  }
  neighbors
}

///|
fn factors_connect(
  factors : Array[Factor],
  left : String,
  right : String,
) -> Bool {
  for factor in factors {
    let names = factor.variable_names()
    if contains_name(names, left) && contains_name(names, right) {
      return true
    }
  }
  false
}
