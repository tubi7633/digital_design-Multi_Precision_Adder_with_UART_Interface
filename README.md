# 512-bit Multi-Precision Adder with UART Interface

A 512-bit multi-precision adder/subtractor implemented on an FPGA (PYNQ-Z2), with a UART interface for communication with a host PC. The project explores and compares four different adder microarchitectures — **Ripple Carry**, **Carry Lookahead (Kogge–Stone)**, **Carry Select**, and a **Hybrid Carry Select–Lookahead** — in terms of speed, area, and power.

---

## Overview

The system receives two 512-bit operands from a host Python application over UART, performs addition (or subtraction, in the main configuration), and sends the result back. Because the internal adder width is configurable (16 / 32 / 64 / 128 / 256 bits), the 512-bit operation is processed in multiple cycles by the `mp_adder` module.

| Adder Width | Architecture        | Total Cycles (512-bit op) |
|-------------|---------------------|---------------------------|
| 16 bits     | Ripple Carry (RCA)  | 33                        |
| 32 bits     | Ripple Carry (RCA)  | 17                        |
| 64 bits     | Carry Select (CSA)  | 9                         |
| 128 bits    | CSA / Hybrid        | 5                         |
| 256 bits    | Carry Lookahead     | 3                         |

---

## Architecture

The design is organized around two main modules:

### 1. UART Top Module (`uart_top.v`)
Top-level controller and I/O interface. Implements an FSM that handles UART reception, computation triggering, and UART transmission.

**FSM states:**
- `IDLE` — system initialization, waits for an operation to start.
- `RX_OP` *(only in add+sub variant)* — receives the operation opcode.
- `WAIT_RX` — waits for a new UART byte before storing operand data.
- `RX` — receives bytes into operand A or B until both are fully loaded.
- `ADD` — triggers the multi-precision adder and waits for completion.
- `WAIT_TX` — waits for the UART transmitter to be ready.
- `TX` — sends the result back to the host, byte by byte.
- `DONE` — final state, ready for a new operation.

### 2. Multi-Precision Adder (`mp_adder.v`)
Performs the actual arithmetic by chunking the 512-bit operands into smaller pieces and feeding them iteratively to a configurable internal adder. Subtraction is implemented via two's complement (operand B is bitwise inverted, with a carry-in of 1).

> ⚠️ **Note:** subtraction is hardcoded for the 256-bit configuration. Lower-width adder variants are tested with addition only, using a simplified `uart_top` variant.

### Adder variants implemented
- **Ripple Carry Adder** (`ripple_carry_adder_Nb.v`) — simplest, smallest, slowest.
- **Carry Lookahead Adder** (`carry_lookahead_adder.v`) — Kogge–Stone parallel-prefix tree, `log2(WIDTH)` stages (8 stages at 256 bits). Fastest but largest.
- **Carry Select Adder** (`carry_select_adder.v`) — block-based, dual ripple adders per block selected by carry-in.
- **Hybrid Carry Select–Lookahead** (`hybrid_carry_select_lookahead_adder.v`) — CSA structure with CLA blocks instead of ripple blocks.

---

## Performance Comparison

| Feature           | Ripple (32b) | CLA (256b)  | CSA (128b)  | Hybrid (128b) |
|-------------------|--------------|-------------|-------------|---------------|
| Cycles            | 17           | **3**       | 5           | 5             |
| Critical Path     | **6.153 ns** | 7.063 ns    | 7.548 ns    | 7.430 ns      |
| Total Add Time    | 104.6 ns     | **21.19 ns**| 37.74 ns    | 37.15 ns      |
| Area (LUTs)       | **1482**     | 4052        | 1727        | 1798          |
| Total On-Chip Power | 0.121 W    | 0.168 W     | 0.123 W     | 0.124 W       |

*Total Add Time = Cycles × Critical Path Delay*

**Key takeaways:**
- The **CLA** delivers the fastest end-to-end addition (~5× faster than RCA), at the cost of ~2.7× more LUTs and the highest power.
- The **RCA** wins on area and power but is unacceptably slow for wide operands.
- **CSA** and **Hybrid** sit in the middle — a sensible compromise for area-constrained designs that still need decent throughput.

---

## Repository Structure

```
LAB4_CDD/
├── LAB4_CDD.srcs/
│   ├── sources_1/
│   │   ├── new/
│   │   │   ├── uart_top.v                          # Top-level FSM + UART I/O
│   │   │   ├── uart_rx.v                           # UART receiver
│   │   │   ├── uart_tx.v                           # UART transmitter
│   │   │   ├── carry_lookahead_adder.v             # Kogge–Stone CLA
│   │   │   ├── carry_select_adder.v                # Carry Select Adder
│   │   │   ├── hybrid_carry_select_lookahead_adder.v
│   │   │   ├── pfa.v                               # Partial full adder
│   │   │   └── Debounce_Switch.v
│   │   ├── imports/
│   │   │   ├── Downloads/mp_adder.v                # Multi-precision adder
│   │   │   └── new/
│   │   │       ├── full_adder.v
│   │   │       └── ripple_carry_adder_Nb.v
│   │   └── bd/design_1/                            # Vivado block design
│   ├── constrs_1/new/PYNQ-Z2v1.0.xdc               # Board constraints
│   └── sim_1/new/                                  # Testbenches
│       ├── uart_top_TB.v
│       ├── uart_rx_TB.v
│       ├── uart_tx_TB.v
│       └── mp_adder_TB.v
└── LAB4_CDD.xpr                                    # Vivado project file
```

---

## Getting Started

### Requirements
- **Xilinx Vivado** 2020.1 (or compatible)
- **PYNQ-Z2** development board
- **Python 3** with `pyserial` on the host PC

### Build and program the FPGA
1. Open `LAB4_CDD.xpr` in Vivado.
2. Run synthesis and implementation.
3. Generate the bitstream.
4. Program the PYNQ-Z2 over JTAG.

### Selecting an adder variant
The internal adder architecture and width are set via parameters in `mp_adder.v` / `uart_top.v`. Edit the `ADDER_WIDTH` parameter (and the instantiated adder module) before re-synthesizing. The default top-level configuration is **256-bit Kogge–Stone CLA**, which supports both addition and subtraction.

### Communicating from the host
Send two 512-bit operands (64 bytes each) over UART at the configured baud rate, then read back the 513-bit result (66 bytes) for addition or 512-bit (64 bytes) result for subtraction.
