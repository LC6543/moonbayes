///|
/// The maximum number of entries a factor table may contain.
///
/// The limit keeps malformed domains from exhausting memory before a caller
/// has a chance to validate its model.
pub const MAX_FACTOR_VALUES : Int32 = 16777216

///|
/// A finite discrete variable.
pub struct Variable {
  priv name : String
  priv size : Int32
} derive(Eq)

///|
pub extend Variable with Eq::{equal, not_equal}

///|
/// Creates a variable with a non-empty name and a positive finite domain.
pub fn Variable::new(
  name : String,
  size : Int32,
) -> Result[Variable, FactorError] {
  if name == "" {
    return Err(EmptyVariableName)
  }
  if size <= 0 {
    return Err(InvalidDomainSize(size))
  }
  Ok(Variable::{ name, size, })
}

///|
/// Returns the variable name.
pub fn Variable::name(self : Variable) -> String {
  self.name
}

///|
/// Returns the number of values in the variable domain.
pub fn Variable::size(self : Variable) -> Int32 {
  self.size
}

///|
/// Errors produced while constructing or combining factor tables.
pub enum FactorError {
  EmptyVariableName
  InvalidDomainSize(Int32)
  DuplicateVariable(String)
  UnknownVariable(String)
  IncompatibleVariable(String, Int32, Int32)
  AssignmentLengthMismatch(Int32, Int32)
  AssignmentOutOfRange(Int32, Int32, Int32)
  IndexOutOfBounds(Int32, Int32)
  ValueCountMismatch(Int32, Int32)
  NegativeValue(Int32)
  NonFiniteValue(Int32)
  ZeroMass
  TableTooLarge(Int32)
} derive(Eq)

///|
pub extend FactorError with Eq::{equal, not_equal}

///|
/// Returns a human-readable explanation of a factor error.
pub fn FactorError::message(self : FactorError) -> String {
  match self {
    EmptyVariableName => "variable name must not be empty"
    InvalidDomainSize(size) =>
      "domain size must be positive, got " + size.to_string()
    DuplicateVariable(name) => "variable appears more than once: " + name
    UnknownVariable(name) => "variable is not in this factor: " + name
    IncompatibleVariable(name, left, right) =>
      "variable " +
      name +
      " has incompatible domain sizes " +
      left.to_string() +
      " and " +
      right.to_string()
    AssignmentLengthMismatch(expected, actual) =>
      "assignment length must be " +
      expected.to_string() +
      ", got " +
      actual.to_string()
    AssignmentOutOfRange(position, value, size) =>
      "assignment value " +
      value.to_string() +
      " at position " +
      position.to_string() +
      " is outside domain size " +
      size.to_string()
    IndexOutOfBounds(index, count) =>
      "factor index " +
      index.to_string() +
      " is outside table length " +
      count.to_string()
    ValueCountMismatch(expected, actual) =>
      "factor needs " +
      expected.to_string() +
      " values, got " +
      actual.to_string()
    NegativeValue(index) =>
      "factor value at index " + index.to_string() + " must not be negative"
    NonFiniteValue(index) =>
      "factor value at index " + index.to_string() + " must be finite"
    ZeroMass => "factor has zero or invalid total mass"
    TableTooLarge(limit) =>
      "factor table exceeds the supported limit of " +
      limit.to_string() +
      " values"
  }
}

///|
/// A dense factor table over an ordered list of finite discrete variables.
///
/// Values use row-major order: the last variable changes fastest. For
/// variables `A(2), B(3)`, the assignments are `(0,0), (0,1), (0,2),
/// (1,0), (1,1), (1,2)`.
pub struct Factor {
  priv variables : Array[Variable]
  priv values : Array[Double]
}

///|
/// Creates a factor from its scope and a complete dense table.
///
/// Names must be unique, every value must be finite and non-negative, and the
/// table length must equal the product of all domain sizes.
pub fn Factor::new(
  variables : Array[Variable],
  values : Array[Double],
) -> Result[Factor, FactorError] {
  let expected = match factor_table_size(variables) {
    Ok(size) => size
    Err(error) => return Err(error)
  }
  if values.length() != expected {
    return Err(ValueCountMismatch(expected, values.length()))
  }
  let mut index = 0
  while index < values.length() {
    match validate_factor_value(values[index], index) {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
    index += 1
  }
  Ok(Factor::{ variables: variables.copy(), values: values.copy(), })
}

///|
/// Returns the factor scope in table order.
pub fn Factor::scope(self : Factor) -> Array[Variable] {
  self.variables.copy()
}

///|
/// Returns the variable names in table order.
pub fn Factor::variable_names(self : Factor) -> Array[String] {
  Array::makei(self.variables.length(), index => self.variables[index].name())
}

///|
/// Returns the number of variables in the factor scope.
pub fn Factor::variable_count(self : Factor) -> Int32 {
  self.variables.length()
}

///|
/// Returns the number of entries in the dense table.
pub fn Factor::value_count(self : Factor) -> Int32 {
  self.values.length()
}

///|
/// Returns a copy of the factor table.
pub fn Factor::values(self : Factor) -> Array[Double] {
  self.values.copy()
}

///|
/// Returns the table index for an assignment in scope order.
pub fn Factor::index_of(
  self : Factor,
  assignment : Array[Int32],
) -> Result[Int32, FactorError] {
  validate_assignment(self.variables, assignment)
}

///|
/// Returns the assignment represented by a dense table index.
pub fn Factor::assignment_at(
  self : Factor,
  index : Int32,
) -> Result[Array[Int32], FactorError] {
  if index < 0 || index >= self.values.length() {
    return Err(IndexOutOfBounds(index, self.values.length()))
  }
  Ok(index_to_assignment(self.variables, index))
}

///|
/// Looks up one entry by assignment.
pub fn Factor::value_at(
  self : Factor,
  assignment : Array[Int32],
) -> Result[Double, FactorError] {
  let index = match validate_assignment(self.variables, assignment) {
    Ok(index) => index
    Err(error) => return Err(error)
  }
  Ok(self.values[index])
}

///|
/// Returns the sum of all entries in the factor table.
pub fn Factor::total(self : Factor) -> Double {
  let mut total = 0.0
  for value in self.values {
    total += value
  }
  total
}

///|
/// Returns a normalized copy whose entries sum to one.
pub fn Factor::normalize(self : Factor) -> Result[Factor, FactorError] {
  let total = self.total()
  if total <= 0.0 || total.is_nan() || total.is_inf() {
    return Err(ZeroMass)
  }
  let normalized = Array::make(self.values.length(), 0.0)
  let mut index = 0
  while index < self.values.length() {
    let value = self.values[index] / total
    match validate_factor_value(value, index) {
      Ok(_) => normalized[index] = value
      Err(error) => return Err(error)
    }
    index += 1
  }
  Factor::new(self.variables, normalized)
}

///|
/// Multiplies two factors over the union of their scopes.
///
/// Shared variables must have the same domain size. The result preserves the
/// left factor's variable order, followed by new right-hand variables.
pub fn Factor::multiply(
  self : Factor,
  other : Factor,
) -> Result[Factor, FactorError] {
  let union_variables = self.variables.copy()
  for variable in other.variables {
    match find_variable(union_variables, variable.name()) {
      Some(existing) =>
        if existing.size() != variable.size() {
          return Err(
            IncompatibleVariable(
              variable.name(),
              existing.size(),
              variable.size(),
            ),
          )
        }
      None => union_variables.push(variable)
    }
  }
  let result_count = match factor_table_size(union_variables) {
    Ok(size) => size
    Err(error) => return Err(error)
  }
  let result_values = Array::make(result_count, 0.0)
  let mut index = 0
  while index < result_count {
    let assignment = index_to_assignment(union_variables, index)
    let left_index = scope_index(self, union_variables, assignment)
    let right_index = scope_index(other, union_variables, assignment)
    let value = self.values[left_index] * other.values[right_index]
    match validate_factor_value(value, index) {
      Ok(_) => result_values[index] = value
      Err(error) => return Err(error)
    }
    index += 1
  }
  Factor::new(union_variables, result_values)
}

///|
/// Sums out every variable that is not listed in `retained`.
///
/// The retained names also define the result order. Duplicate or unknown
/// names are rejected.
pub fn Factor::marginalize(
  self : Factor,
  retained : Array[String],
) -> Result[Factor, FactorError] {
  let retained_variables : Array[Variable] = []
  for name in retained {
    if find_variable(retained_variables, name) is Some(_) {
      return Err(DuplicateVariable(name))
    }
    match find_variable(self.variables, name) {
      Some(variable) => retained_variables.push(variable)
      None => return Err(UnknownVariable(name))
    }
  }
  let result_count = match factor_table_size(retained_variables) {
    Ok(size) => size
    Err(error) => return Err(error)
  }
  let result_values = Array::make(result_count, 0.0)
  let mut index = 0
  while index < self.values.length() {
    let assignment = index_to_assignment(self.variables, index)
    let retained_assignment = Array::make(retained_variables.length(), 0)
    let mut position = 0
    while position < retained_variables.length() {
      let source_position = find_variable_position(
        self.variables,
        retained_variables[position].name(),
      )
      if source_position >= 0 {
        retained_assignment[position] = assignment[source_position]
      }
      position += 1
    }
    let retained_index = assignment_to_index(
      retained_variables, retained_assignment,
    )
    result_values[retained_index] += self.values[index]
    index += 1
  }
  Factor::new(retained_variables, result_values)
}

///|
fn factor_table_size(variables : Array[Variable]) -> Result[Int32, FactorError] {
  let mut total = 1
  let mut position = 0
  while position < variables.length() {
    let name = variables[position].name()
    let mut previous = 0
    while previous < position {
      if variables[previous].name() == name {
        return Err(DuplicateVariable(name))
      }
      previous += 1
    }
    let size = variables[position].size()
    if size <= 0 {
      return Err(InvalidDomainSize(size))
    }
    if total > MAX_FACTOR_VALUES / size {
      return Err(TableTooLarge(MAX_FACTOR_VALUES))
    }
    total *= size
    position += 1
  }
  Ok(total)
}

///|
fn validate_factor_value(
  value : Double,
  index : Int32,
) -> Result[Unit, FactorError] {
  if value.is_nan() || value.is_inf() {
    Err(NonFiniteValue(index))
  } else if value < 0.0 {
    Err(NegativeValue(index))
  } else {
    Ok(())
  }
}

///|
fn find_variable_position(variables : Array[Variable], name : String) -> Int32 {
  let mut position = 0
  while position < variables.length() {
    if variables[position].name() == name {
      return position
    }
    position += 1
  }
  -1
}

///|
fn find_variable(variables : Array[Variable], name : String) -> Variable? {
  let position = find_variable_position(variables, name)
  if position >= 0 {
    Some(variables[position])
  } else {
    None
  }
}

///|
fn validate_assignment(
  variables : Array[Variable],
  assignment : Array[Int32],
) -> Result[Int32, FactorError] {
  if assignment.length() != variables.length() {
    return Err(
      AssignmentLengthMismatch(variables.length(), assignment.length()),
    )
  }
  let mut index = 0
  let mut stride = 1
  let mut position = variables.length() - 1
  while position >= 0 {
    let value = assignment[position]
    let size = variables[position].size()
    if value < 0 || value >= size {
      return Err(AssignmentOutOfRange(position, value, size))
    }
    index += value * stride
    stride *= size
    position -= 1
  }
  Ok(index)
}

///|
fn index_to_assignment(
  variables : Array[Variable],
  index : Int32,
) -> Array[Int32] {
  let assignment = Array::make(variables.length(), 0)
  let mut remaining = index
  let mut position = variables.length() - 1
  while position >= 0 {
    let size = variables[position].size()
    assignment[position] = remaining % size
    remaining /= size
    position -= 1
  }
  assignment
}

///|
fn assignment_to_index(
  variables : Array[Variable],
  assignment : Array[Int32],
) -> Int32 {
  let mut index = 0
  let mut stride = 1
  let mut position = variables.length() - 1
  while position >= 0 {
    index += assignment[position] * stride
    stride *= variables[position].size()
    position -= 1
  }
  index
}

///|
fn scope_index(
  factor : Factor,
  scope : Array[Variable],
  assignment : Array[Int32],
) -> Int32 {
  let mut index = 0
  let mut stride = 1
  let mut position = factor.variables.length() - 1
  while position >= 0 {
    let variable = factor.variables[position]
    let scope_position = find_variable_position(scope, variable.name())
    if scope_position >= 0 {
      index += assignment[scope_position] * stride
    }
    stride *= variable.size()
    position -= 1
  }
  index
}
