FemtoRV-Morph - Notes
=====================

Mission statement: create a Risc-V processor with an _interesting_
capabilities/complexity/performance ratio. The main idea is to start from
an RV32ICZicsr core like Gracilis, add the instructions that have an
interesting area/performance ratio (e.g., MUL variants and a subset of RV32F)
and implement the rest in software traps. There would be two versions,
Caterpillar and QuickSilver (abbreviated Hg).

FemtoRVMorph-Caterpillar
========================

- RV32ICZicsr (Gracilis base)

- RV32M: MUL, MULH, MULHSU, MULHU (DIV, DIVU, REM, REMU in sw trap)

- Implement a subset of RV32F (separate fp registers) or Zfinx (shared registers)
  Zfinx may be the way to go (much simpler datapath, smaller nb instructions),
  and Zfinx could be used to emulate RV32F in trap !

  It is mostly a FMA (Fused-Multiply-Add) unit, used to implement:
   - Sum and product: FADD, FSUB, FMUL, FMADD, FMSUB, FNMADD, FNMSUB
   - Comparison: FEQ, FLT, FLE
   - Load/Store (RV32F): FLW, FSW
   - integer reg <-> fp reg (RV32F): FMVXW, FMVWX
   - All the rest in sw trap

- Questions:
   - RV32F or Zfinx ?
   - single-precision or double-precision ?

FemtoRVMorph-Hg (QuickSilver)
=============================

- Pipelined with branch prediction
- I$, D$ caches
- MCT (Minimal Cost Trap) mechanism: cooperation between illegal instruction
  trap mechanism and address prediction logic, fast context switch logic
- Pipelined FMA unit
- Some sort of Conway/Scoreboard/Tomasulo dynamic execution mechanism to make
  best use of pipelined FMA unit

- Questions:
   - RV32F or Zfinx ? Probably start with Zfinx (one difficulty at a time:
     more complicated RV32F datapath will be harder with pipeline), then
     "morph" it to RV32F
   - single-precision or double-precision ? Depends on FPGA capabilities.
   - other instructions in hw:
      - vector math
      - extensions implemented by Hazard3 (huge performance gain it seems)
