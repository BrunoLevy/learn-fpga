# RISCOF

RISC-V ISA unit testing using the RISCOF framework.

Tests can be run by executing the script [`buld.sh`](build.sh).
The script should setup the Python virtual environment and run the tests for processors `mouse` and `degu`.
Since the Python code is taken from Git development branches, there might be
[unexpected failures](https://github.com/riscv-software-src/riscof/issues/147).

```
cd riscof
./buld.sh
```

## Requirements

Follow the [RISCOF Quickstart guide](https://riscof.readthedocs.io/en/stable/installation.html)
to install a RV32 GCC, and reference simulators Spike and/or Sail.

### RISC-V GCC compiler

It can be compiled from sources, extracted from a tarball or
installed using a Linux distribution package manager.

For this instructions, GCC is expected to be installed into `/opt/riscv-gcc`.
If installed elsewhere, use a different `PATH` environment variable setting later in the instructions.

### RISC-V Spike simulator

This is currently the preferred simulator, mostly because it is easier to install than Sail.

NOTE: The current execution trace log created by the HDL simulation only matches the Spike simulator.

### RISC-V Sail simulator

Either compile from sources following the [official instructions](https://github.com/riscv/sail-riscv?tab=readme-ov-file#building-the-model),
or preferably download a precompiled release tarball.

NOTE: Support for execution trace log compatible with Sail might be added in the future.

## Setting up the environment

Setup the `python3` virtual environment and install a working version of RISCOF.

```sh
cd riscof
python3 -m venv .venv
source .venv/bin/activate
pip3 install git+https://github.com/riscv/riscof.git@d38859f
```

Setup the `PATH` environment variable to gain access to tool executables.

```sh
source ../settings-questa.sh
source ../settings-vivado.sh
export PATH=/opt/riscv-isa-sim/bin/:$PATH
export PATH=/opt/riscv-gcc/bin/:$PATH
export PATH=`git rev-parse --show-toplevel`/submodules/sail-riscv/build/c_emulator/:$PATH
```

To exit the virtual environment:

```sh
deactivate
```

To reenter an existing virtual environment, just redo the activation:

```sh
source .venv/bin/activate
```

In a reactivated virtual environment the `PATH`
environmental variable updates must be rerun.

## Running RISCOF tests

To run the tests inside the virtual environment execute:

```sh
riscof run --config=config-mouse.ini --suite=../submodules/riscv-arch-test/riscv-test-suite/ --env=../submodules/riscv-arch-test/riscv-test-suite/env
```

Currently only `mouse` and `degu` CPUs are available for testing.

## Implementation details

### HDL testbench

The SystemVerilog testbench is composed from the following modules:

| DUT              | mouse                                                                    | degu                                                                     |
|------------------|--------------------------------------------------------------------------|--------------------------------------------------------------------------|
| testbench TOP    | [`r5p_mouse_riscof_tb`](../hdl/tbn/riscof/r5p_mouse_riscof_tb.sv)        | [`r5p_degu_riscof_tb`](../hdl/tbn/riscof/r5p_degu_riscof_tb.sv)          |
| CPU core         | [`r5p_mouse`](../hdl/rtl/mouse/r5p_mouse.sv)                             | [`r5p_degu`](../hdl/rtl/degu/r5p_degu.sv)                                |
| trace logger     | [`r5p_mouse_trace_spike`](../hdl/tbn/riscof/r5p_mouse_trace_spike.sv)    | [`r5p_degu_trace_spike`](../hdl/riscof/tbn/r5p_degu_trace_spike.sv)      |
| HTIF             | [`r5p_htif`](../hdl/tbn/htif/r5p_htif.sv)                                | [`r5p_htif`](../hdl/tbn/htif/r5p_htif.sv)                                |
| memory model     | [`tcb_vip_memory` 1 IF](../submodules/tcb/hdl/tbn/vip/tcb_vip_memory.sv) | [`tcb_vip_memory` 2 IF](../submodules/tcb/hdl/tbn/vip/tcb_vip_memory.sv) |
| TCB interconnect | ... | ... |

## HDL simulator `Makefile`

Further details on how the simulator Makefile works see the [`README`](../sim/README.md).

The RISCOF framework is passing additional arguments to the HDL testbench.
In case of SystemVerilog this are runtime arguments (`$plusargs`).

This arguments are:

- symbols from the Elf file:
  - HTIF interface `tohost`/`fromhost`,
  - signature start/stop,
- file paths:
  - Elf dump in `bin`/`hex` format,
  - execution trace log.

## Debugging

RISCOF with details from the `ini` and Python plugin will generate a Makefile (`riscof_work/Makefile.DUT-r5p`)
containing individual tests from `riscv-arch-test` as numbered targets.

You can rerun an individual target for a failing testcase.
Search `riscof_work/Makefile.DUT-r5p` for the testcase name and remember the targer number.

```sh
make -C riscof_work/ -f Makefile.DUT-r5p TARGET0
```

The Questa and Vivado simulator makefiles have a `gui` target,
if uncommented, the Makefile will open the GUI, where you can observe waveforms.

To identify the point where DUT simulation strts diferring from the reference,
go to the testcase folder (in the given example TARGET0 matches `riscof_work/rv32i_m/I/src/add-01.S/`).
Using your preferred diff tool compare the execution trace log produced by the reference against the DUT log.

```sh
diff ref/ref.log dut/dut.log
```

# References

Alternative approach to a written execution trace log, by compiling `spike` as a library:

https://spinalhdl.github.io/NaxRiscv-Rtd/main/NaxRiscv/simulation/index.html

https://groups.google.com/a/groups.riscv.org/g/hw-dev/c/kerAQ_ZAGIk

Alternative RISC-V simulator:

https://www.intel.com/content/www/us/en/developer/articles/tool/simics-simulator.html
