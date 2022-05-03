# FemtoRV processor collection

FemtoRV is a collection of small and understandable RISC-V processors.

See this table to choose the most suitable one for your project!

File name                 | ISA            | Special capabilities
------------------------- | -------------- | --------
femtorv32_quark.v         | RV32I          | The smallest core in this collection, perfect for tiny FPGAs. For size reasons, it shifts only one bit per clock cycle.
femtorv32_quark_bicycle.v | RV32I          | The simplest and fastest - in terms of cycles/instruction - core in this collection. Basically Quark with a barrel shifter and additional multiplexers. Recommended if you can afford a few more LUTs and just need a vanilla RV32I.
femtorv32_tachyon.v       | RV32I          | Quark with execute cycle split in two in order to achieve a higher maximum clock frequency, but at the expense of more cycles per instruction.
femtorv32_electron.v      | RV32IM         | Featuring barrel shifter, multiplication and division instructions.
femtorv32_intermissum.v   | RV32IM + IRQ   | Full interrupt support along with CSR registers.
femtorv32_gracilis.v      | RV32IMC + IRQ  | With compressed instructions support, saves both RAM usage and memory fetch cycles. Recommended as general-purpose processor.
femtorv32_individua.v     | RV32IMAC + IRQ | Also available with atomic instructions support. Not really necessary in single processor designs, but probably useful if you have tricky interrupt handlers.
femtorv32_petitbateau.v   | RV32IMFC + IRQ | Floating point!
