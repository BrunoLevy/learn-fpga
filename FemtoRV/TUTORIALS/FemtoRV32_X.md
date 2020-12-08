Episode X: Adding load and store instructions
------------------------------------------

We are nearly there ! However, adding `load` and `store` requires some drastic additions to the design. Let us start from what's easy, the
instruction decoder. We are generating two additional signals `isLoad` and `isStore`. There are two more cases in the big `switch` statement:

```
           7'b0000011: begin // Load
	      writeBackEn = 1'b1;     // enable write back
	      writeBackSel = 4'b0100; // write back source = RAM
	      aluInSel1 = 1'b0;       // ALU source 1 = reg
	      aluInSel2 = 1'b1;       // ALU source 2 = imm
	      aluSel = 1'b0;          // ALU op = ADD
	      imm = Iimm;             // imm format = I
	      isLoad = 1'b1;
	   end
	 
           7'b0100011: begin // Store
	      writeBackEn = 1'b0;     // disable write back
	      writeBackSel = 4'bxxxx; // write back sel = don't care
	      aluInSel1 = 1'b0;       // ALU source 1 = reg
	      aluInSel2 = 1'b1;       // ALU source 2 = imm
	      aluSel = 1'b0;          // ALU op = ADD
	      imm = Simm;             // imm format = S
	      isStore = 1'b1;
	   end
```

Everything is connected as shown in this schematic. There is a new _memory access subsystem_. To make things easy, we are
going to use different wires for reading and for writing data. 

![](Images/FemtoRV32_design.jpg)

One difficulty remains: the same wires are used to read the instructions and to read the data. How can be route instructions
to the `instr` register and data to register writeback ? To handle that, the finite state machine gets a bit more complicated. 

TO BE CONTINUED.
