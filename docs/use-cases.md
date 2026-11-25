# Use Cases

## Equipment diagnosis

Model component faults, observable alarms, and sensor evidence as finite
variables. Use exact posterior queries to rank likely causes and use MAP to
return the most probable diagnosis.

## Risk and reliability analysis

Encode failure modes and operating conditions as a DAG. Evidence likelihood
provides reproducible scenario probabilities, while d-separation checks make
assumptions about independent and dependent factors explicit.

## Embedded decision support

The core package has no I/O dependencies and runs on the checked Wasm targets.
It can evaluate small and medium discrete networks inside browser or edge
applications without a Python service.

## Simulation and data preparation

Ancestral sampling produces complete reproducible synthetic datasets. Complete
data fitting can then rebuild CPTs with configurable smoothing, while JSON
import and export keep generated models inspectable and portable.
