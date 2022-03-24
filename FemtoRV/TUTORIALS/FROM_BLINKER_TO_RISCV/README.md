# From Blinker to RISC-V

A progressive journey from a simple blinky design to a RISC-V core.

_WIP_

## Prerequisites:
- iverilog(icarus) 

```
  sudo apt-get install iverilog
```

## Instructions

To start a simulation:
```
   $ run.sh stepnn.v
```

To exit the simulation:
```
  <ctrl><c>
  finish
```

## The steps

- [step 1](step1.v): Blinker, too fast, can't see anything
- [step 2](step2.v): Blinker with clockworks
- [step 3](step3.v): Blinker that loads pattern from RAM
- [step 4](step4.v): The instruction decoder
- [step 5](step5.v): The register bank and the state machine
- [step 6](step6.v): The ALU
- [step 7](step7.v): Using the VERILOG assembler
- [step 8](step8.v): Jumps
- [step 9](step9.v): Branches
- [step 10](step10.v): LUI and AUIPC
- [step 11](step11.v): Memory in separate module
- [step 12](step12.v): Subroutines 1 (standard Risc-V instruction set)
- [step 13](step13.v): Size optimization
- [step 14](step14.v): Subroutines 2 (using Risc-V pseudo-instructions)
- [step 15](step15.v): Load
- [step 16](step16.v): Store

_WIP_

- [step 17](step17.v): MUL routine
- step 18: Using the GNU toolchain to compile programs
- step 19: Devices (UART, ...)
