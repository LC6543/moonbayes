///|
/// One variable-elimination bucket in an inference plan.
pub struct InferenceBucket {
  priv variable : String
  priv variables : Array[String]
  priv estimated_entries : Int32
}

///|
/// Returns the variable eliminated by this bucket.
pub fn InferenceBucket::variable(self : InferenceBucket) -> String {
  self.variable
}

///|
/// Returns the multiplied bucket scope.
pub fn InferenceBucket::variables(self : InferenceBucket) -> Array[String] {
  self.variables.copy()
}

///|
/// Returns the estimated dense table size before elimination.
pub fn InferenceBucket::estimated_entries(self : InferenceBucket) -> Int32 {
  self.estimated_entries
}

///|
/// A deterministic variable-elimination execution plan.
pub struct InferencePlan {
  priv elimination_order : Array[String]
  priv buckets : Array[InferenceBucket]
  priv result_entries : Int32
}

///|
/// Returns the order in which hidden variables would be eliminated.
pub fn InferencePlan::elimination_order(self : InferencePlan) -> Array[String] {
  self.elimination_order.copy()
}

///|
/// Returns the number of elimination buckets.
pub fn InferencePlan::bucket_count(self : InferencePlan) -> Int32 {
  self.buckets.length()
}

///|
/// Returns one elimination bucket.
pub fn InferencePlan::bucket(
  self : InferencePlan,
  index : Int32,
) -> InferenceBucket? {
  if index < 0 || index >= self.buckets.length() {
    None
  } else {
    Some(self.buckets[index])
  }
}

///|
/// Returns the largest estimated bucket table size.
pub fn InferencePlan::max_bucket_size(self : InferencePlan) -> Int32 {
  let mut maximum = 0
  for bucket in self.buckets {
    if bucket.estimated_entries() > maximum {
      maximum = bucket.estimated_entries()
    }
  }
  maximum
}

///|
/// Returns the estimated size of the final target table.
pub fn InferencePlan::result_entries(self : InferencePlan) -> Int32 {
  self.result_entries
}

///|
/// Builds an execution plan for an exact posterior query without allocating
/// dense probability tables.
pub fn BayesianNetwork::inference_plan(
  self : BayesianNetwork,
  targets : Array[String],
  evidence : Array[(String, Int32)],
) -> Result[InferencePlan, InferenceError] {
  if targets.length() == 0 {
    return Err(EmptyQuery)
  }
  let target_variables : Array[Variable] = []
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
    position += 1
  }
  match validate_network_evidence(self, evidence) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  for entry in evidence {
    if contains_name(targets, entry.0) {
      return Err(TargetIsEvidence(entry.0))
    }
  }
  let mut scopes : Array[PlanScope] = []
  for node in self.nodes {
    scopes.push(PlanScope::{
      variables: scope_without_evidence(node.distribution().scope(), evidence),
    })
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
  let buckets : Array[InferenceBucket] = []
  let elimination_order : Array[String] = []
  while candidates.length() > 0 {
    let variable = choose_plan_variable(scopes, candidates)
    let selected : Array[PlanScope] = []
    let remaining : Array[PlanScope] = []
    for scope in scopes {
      if scope_has_variable(scope, variable) {
        selected.push(scope)
      } else {
        remaining.push(scope)
      }
    }
    if selected.length() > 0 {
      let bucket_scope = combine_plan_scopes(selected)
      let bucket_names = plan_scope_names(bucket_scope)
      let estimated_entries = match factor_table_size(bucket_scope.variables) {
        Ok(size) => size
        Err(error) => return Err(FactorFailure(error))
      }
      buckets.push(InferenceBucket::{
        variable,
        variables: bucket_names,
        estimated_entries,
      })
      elimination_order.push(variable)
      remaining.push(PlanScope::{
        variables: scope_without_name(bucket_scope, variable),
      })
    }
    scopes = remaining
    candidates = names_without(candidates, variable)
  }
  let result_entries = match factor_table_size(target_variables) {
    Ok(size) => size
    Err(error) => return Err(FactorFailure(error))
  }
  Ok(InferencePlan::{ elimination_order, buckets, result_entries, })
}

///|
priv struct PlanScope {
  variables : Array[Variable]
}

///|
fn scope_without_evidence(
  variables : Array[Variable],
  evidence : Array[(String, Int32)],
) -> Array[Variable] {
  let result : Array[Variable] = []
  for variable in variables {
    if !evidence_contains(evidence, variable.name()) {
      result.push(variable)
    }
  }
  result
}

///|
fn scope_without_name(scope : PlanScope, removed : String) -> Array[Variable] {
  let result : Array[Variable] = []
  for variable in scope.variables {
    if variable.name() != removed {
      result.push(variable)
    }
  }
  result
}

///|
fn scope_has_variable(scope : PlanScope, name : String) -> Bool {
  for variable in scope.variables {
    if variable.name() == name {
      return true
    }
  }
  false
}

///|
fn combine_plan_scopes(scopes : Array[PlanScope]) -> PlanScope {
  let variables : Array[Variable] = []
  for scope in scopes {
    for variable in scope.variables {
      if find_variable(variables, variable.name()) is None {
        variables.push(variable)
      }
    }
  }
  PlanScope::{ variables, }
}

///|
fn plan_scope_names(scope : PlanScope) -> Array[String] {
  Array::makei(scope.variables.length(), index => scope.variables[index].name())
}

///|
fn choose_plan_variable(
  scopes : Array[PlanScope],
  candidates : Array[String],
) -> String {
  let mut best = candidates[0]
  let mut best_fill = plan_fill_edges(scopes, best)
  let mut position = 1
  while position < candidates.length() {
    let candidate = candidates[position]
    let fill = plan_fill_edges(scopes, candidate)
    if fill < best_fill {
      best = candidate
      best_fill = fill
    }
    position += 1
  }
  best
}

///|
fn plan_fill_edges(scopes : Array[PlanScope], variable : String) -> Int32 {
  let neighbors = plan_neighbors(scopes, variable)
  let mut fill = 0
  let mut left = 0
  while left < neighbors.length() {
    let mut right = left + 1
    while right < neighbors.length() {
      if !plan_scopes_connect(scopes, neighbors[left], neighbors[right]) {
        fill += 1
      }
      right += 1
    }
    left += 1
  }
  fill
}

///|
fn plan_neighbors(
  scopes : Array[PlanScope],
  variable : String,
) -> Array[String] {
  let neighbors : Array[String] = []
  for scope in scopes {
    if scope_has_variable(scope, variable) {
      for candidate in scope.variables {
        if candidate.name() != variable &&
          !contains_name(neighbors, candidate.name()) {
          neighbors.push(candidate.name())
        }
      }
    }
  }
  neighbors
}

///|
fn plan_scopes_connect(
  scopes : Array[PlanScope],
  left : String,
  right : String,
) -> Bool {
  for scope in scopes {
    if scope_has_variable(scope, left) && scope_has_variable(scope, right) {
      return true
    }
  }
  false
}
