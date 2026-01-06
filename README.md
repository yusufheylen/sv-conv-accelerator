# SystemVerilog Convolution Accelerator (Hardware Simulation)

A simulated hardware accelerator for 2D convolution written in **SystemVerilog**, developed as part of a KU Leuven hardware acceleration course project.

The goal was to **improve throughput/latency under strict bandwidth and area constraints**, while integrating with a provided verification environment (ready/valid handshakes, testbench infrastructure).

---

## What this project is
This repository contains:
- A convolution “accelerator” implemented as synthesizable-style SystemVerilog (simulation-focused).
- A course-style SystemVerilog testbench (transactions / driver / monitor / scoreboard).
- A top-level system wrapper and controller logic implementing an optimized convolution schedule.

---

## My contributions (what I implemented/modified)
I focused on the **architecture/control path and integration**, specifically:
- **Controller FSM** (`controller_fsm.sv`): control sequencing, handshake correctness, scheduling/loop ordering.
- **Top-level integration** (`top_chip.sv`, `top_system.sv`): wiring, control/data orchestration, and system-level integration.
- **Performance-oriented changes**: reworked the convolution execution order (“dataflow”) to increase compute utilisation under the given constraints.

> Note: Some RTL building blocks and/or large parts of the verification environment were provided as starter code by the course staff. My work centres on the controller + top-level design and the performance optimisation choices.

---

## Repository structure
Typical layout:
- `src/device/` — DUT / accelerator RTL (top modules + controller + datapath blocks)
- `src/test/` — verification environment (driver/monitor/scoreboard/transactions/test programs)
- `src/rtl_building_blocks/` — reusable modules (e.g., FIFO, memories, MAC/multiplier blocks)
- `sourcefile_order` — compile order file used by the simulator flow

---

## How to run (QuestaSim example)
This project was tested in a course simulation flow. A typical QuestaSim run looks like:

```bash
# compile (example — adjust to your flow)
vlog -f sourcefile_order

# simulate (example — adjust top name)
vsim -c tbench_top
run -all
quit
