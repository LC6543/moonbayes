///|
/// Returns a new network with one node's local distribution replaced.
pub fn BayesianNetwork::replace_distribution(
  self : BayesianNetwork,
  name : String,
  distribution : Factor,
) -> Result[BayesianNetwork, NetworkError] {
  self.replace_distributions([(name, distribution)])
}

///|
/// Returns a new network with multiple local distributions replaced.
///
/// Replacements are applied to the existing node order and the complete model
/// is revalidated. The original network is not modified.
pub fn BayesianNetwork::replace_distributions(
  self : BayesianNetwork,
  replacements : Array[(String, Factor)],
) -> Result[BayesianNetwork, NetworkError] {
  let mut position = 0
  while position < replacements.length() {
    let name = replacements[position].0
    if find_network_node(self.nodes, name) is None {
      return Err(UnknownNode(name))
    }
    let mut previous = 0
    while previous < position {
      if replacements[previous].0 == name {
        return Err(DuplicateReplacement(name))
      }
      previous += 1
    }
    position += 1
  }
  let nodes : Array[NetworkNode] = []
  for node in self.nodes {
    let replacement = find_replacement_index(replacements, node.variable_name())
    if replacement >= 0 {
      let distribution = replacements[replacement].1
      let rebuilt = match
        NetworkNode::new(node.variable(), node.parents(), distribution) {
        Ok(node) => node
        Err(error) => return Err(error)
      }
      nodes.push(rebuilt)
    } else {
      nodes.push(node)
    }
  }
  BayesianNetwork::new(nodes)
}

///|
/// Returns a new network with one variable renamed.
///
/// The variable domain and all conditional table values are preserved. Every
/// parent reference and distribution scope is renamed consistently.
pub fn BayesianNetwork::rename_variable(
  self : BayesianNetwork,
  old_name : String,
  new_name : String,
) -> Result[BayesianNetwork, NetworkError] {
  if find_network_node(self.nodes, old_name) is None {
    return Err(UnknownNode(old_name))
  }
  if old_name == new_name {
    return Ok(self)
  }
  if find_network_node(self.nodes, new_name) is Some(_) {
    return Err(DuplicateNode(new_name))
  }
  let nodes : Array[NetworkNode] = []
  for node in self.nodes {
    let variable = match
      rename_variable_value(node.variable(), old_name, new_name) {
      Ok(variable) => variable
      Err(error) => return Err(error)
    }
    let parents = node.parents()
    let renamed_parents : Array[String] = []
    for parent in parents {
      if parent == old_name {
        renamed_parents.push(new_name)
      } else {
        renamed_parents.push(parent)
      }
    }
    let scope = node.distribution().scope()
    let renamed_scope : Array[Variable] = []
    for scope_variable in scope {
      let renamed = match
        rename_variable_value(scope_variable, old_name, new_name) {
        Ok(variable) => variable
        Err(error) => return Err(error)
      }
      renamed_scope.push(renamed)
    }
    let distribution = match
      Factor::new(renamed_scope, node.distribution().values()) {
      Ok(factor) => factor
      Err(error) => return Err(FactorFailure(error))
    }
    let rebuilt = match
      NetworkNode::new(variable, renamed_parents, distribution) {
      Ok(node) => node
      Err(error) => return Err(error)
    }
    nodes.push(rebuilt)
  }
  BayesianNetwork::new(nodes)
}

///|
fn rename_variable_value(
  variable : Variable,
  old_name : String,
  new_name : String,
) -> Result[Variable, NetworkError] {
  if variable.name() == old_name {
    match Variable::new(new_name, variable.size()) {
      Ok(variable) => Ok(variable)
      Err(error) => Err(FactorFailure(error))
    }
  } else {
    Ok(variable)
  }
}

///|
fn find_replacement_index(
  replacements : Array[(String, Factor)],
  name : String,
) -> Int32 {
  let mut index = 0
  while index < replacements.length() {
    if replacements[index].0 == name {
      return index
    }
    index += 1
  }
  -1
}
