/*
 * A simple assembler for RiscV written in VERILOG.
 * See table page 104 of RiscV instruction manual.
 * Bruno Levy, March 2022
 */

integer memPC;
initial memPC = 0;

/***************************************************************************/

/*
 * Register names.
 * Looks stupid, but makes assembly code more legible (without it,
 * one does not make the difference between immediate values and 
 * register ids).
 */ 

localparam x0 = 0, x1 = 1, x2 = 2, x3 = 3, x4 = 4, x5 = 5, x6 = 6, x7 = 7, 
           x8 = 8, x9 = 8, x10=10, x11=11, x12=12, x13=13, x14=14, x15=15,
           x16=16, x17=17, x18=18, x19=19, x20=20, x21=21, x22=22, x23=23,
           x24=24, x25=25, x26=26, x27=27, x28=28, x29=29, x30=30, x31=31;


localparam [31:0] NOP_CODEOP = 32'b0000000_00000_00000_000_00000_0110011; // add x0,x0,x0

/***************************************************************************/

/*
 * R-Type instructions.
 * rd <- rs1 OP rs2
 */

task RType;
   input [6:0] opcode;
   input [4:0] rd;   
   input [4:0] rs1;
   input [4:0] rs2;
   input [2:0] funct3;
   input [6:0] funct7;
   begin
      MEM[memPC[31:2]] = {funct7, rs2, rs1, funct3, rd, opcode};
      memPC = memPC + 4;
   end
endtask

task ADD;
   input [4:0] rd;
   input [4:0] rs1;
   input [4:0] rs2;
   RType(7'b0110011, rd, rs1, rs2, 3'b000, 7'b0000000);
endtask
   
task SUB;
   input [4:0] rd;
   input [4:0] rs1;
   input [4:0] rs2;
   RType(7'b0110011, rd, rs1, rs2, 3'b000, 7'b0100000);
endtask

task SLL;
   input [4:0] rd;
   input [4:0] rs1;
   input [4:0] rs2;
   RType(7'b0110011, rd, rs1, rs2, 3'b001, 7'b0000000);
endtask

task SLT;
   input [4:0] rd;
   input [4:0] rs1;
   input [4:0] rs2;
   RType(7'b0110011, rd, rs1, rs2, 3'b010, 7'b0000000);
endtask
   
task SLTU;
   input [4:0] rd;
   input [4:0] rs1;
   input [4:0] rs2;
   RType(7'b0110011, rd, rs1, rs2, 3'b011, 7'b0000000);
endtask

task XOR;
   input [4:0] rd;
   input [4:0] rs1;
   input [4:0] rs2;
   RType(7'b0110011, rd, rs1, rs2, 3'b100, 7'b0000000);
endtask

task SRL;
   input [4:0] rd;
   input [4:0] rs1;
   input [4:0] rs2;
   RType(7'b0110011, rd, rs1, rs2, 3'b101, 7'b0000000);
endtask

task SRA;
   input [4:0] rd;
   input [4:0] rs1;
   input [4:0] rs2;
   RType(7'b0110011, rd, rs1, rs2, 3'b101, 7'b0000010);
endtask

task OR;
   input [4:0] rd;
   input [4:0] rs1;
   input [4:0] rs2;
   RType(7'b0110011, rd, rs1, rs2, 3'b110, 7'b0000000);
endtask

task AND;
   input [4:0] rd;
   input [4:0] rs1;
   input [4:0] rs2;
   RType(7'b0110011, rd, rs1, rs2, 3'b111, 7'b0000000);
endtask

/***************************************************************************/

/*
 * I-Type instructions.
 * rd <- rs1 OP imm
 */
   
task IType;
   input [6:0]  opcode;
   input [4:0]  rd;   
   input [4:0]  rs1;
   input [31:0] imm;
   input [2:0]  funct3;
   begin
      MEM[memPC[31:2]] = {imm[11:0], rs1, funct3, rd, opcode};
      memPC = memPC + 4;
   end
endtask

task ADDI;
   input [4:0]  rd;   
   input [4:0]  rs1;
   input [31:0] imm;
   begin
      IType(7'b0010011, rd, rs1, imm, 3'b000);
   end
endtask

task SLTI;
   input [4:0]  rd;   
   input [4:0]  rs1;
   input [31:0] imm;
   begin
      IType(7'b0010011, rd, rs1, imm, 3'b010);
   end
endtask

task SLTIU;
   input [4:0]  rd;   
   input [4:0]  rs1;
   input [31:0] imm;
   begin
      IType(7'b0010011, rd, rs1, imm, 3'b011);
   end
endtask

task XORI;
   input [4:0]  rd;   
   input [4:0]  rs1;
   input [31:0] imm;
   begin
      IType(7'b0010011, rd, rs1, imm, 3'b100);
   end
endtask

task ORI;
   input [4:0]  rd;   
   input [4:0]  rs1;
   input [31:0] imm;
   begin
      IType(7'b0010011, rd, rs1, imm, 3'b110);
   end
endtask

task ANDI;
   input [4:0]  rd;   
   input [4:0]  rs1;
   input [31:0] imm;
   begin
      IType(7'b0010011, rd, rs1, imm, 3'b111);
   end
endtask

// The three shifts, SLLI, SRLI, SRAI, encoded in RType format
// (rs2 is replaced with shift amount=imm[4:0])   
   
task SLLI;
   input [4:0]  rd;   
   input [4:0]  rs1;
   input [31:0] imm;
   begin
      RType(7'b0010011, rd, rs1, imm[4:0], 3'b001, 7'b0000000);
   end
endtask

task SRLI;
   input [4:0]  rd;   
   input [4:0]  rs1;
   input [31:0] imm;
   begin
      RType(7'b0010011, rd, rs1, imm[4:0], 3'b101, 7'b0000000);
   end
endtask

task SRAI;
   input [4:0]  rd;   
   input [4:0]  rs1;
   input [31:0] imm;
   begin
      RType(7'b0010011, rd, rs1, imm[4:0], 3'b101, 7'b0100000);
   end
endtask

/***************************************************************************/

/*
 * Jumps (JAL and JALR)
 */

task JType;
   input [6:0]  opcode;
   input [4:0]  rd;
   input [31:0] imm;
   begin
      MEM[memPC[31:2]] = {imm[20], imm[10:1], imm[11], imm[19:12], rd, opcode};
      memPC = memPC + 4;
   end
endtask
   
task JAL;
   input [4:0] rd;
   input [31:0] imm;
   begin
      $display("JAL, imm = %d",imm);
      JType(7'b1101111, rd, imm);
   end
endtask 

// JALR is encoded in the IType format.
   
task JALR;
   input [4:0] rd;
   input [4:0] rs1;
   input [31:0] imm;
   begin
      IType(7'b1100111, rd, rs1, imm, 3'b000);
   end
endtask   

/***************************************************************************/   

/*
 * Branch instructions.
 */    
   
task BType;
   input [6:0]  opcode;
   input [4:0]  rs1;
   input [4:0]  rs2;   
   input [31:0] imm;
   input [2:0]  funct3;
   begin
      MEM[memPC[31:2]] = {imm[12],imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], opcode};
      memPC = memPC + 4;
   end
endtask

task BEQ;
   input [4:0]  rs1;
   input [4:0]  rs2;   
   input [31:0] imm;
   begin
      BType(7'b1100011, rs1, rs2, imm, 3'b000);
   end
endtask

task BNE;
   input [4:0]  rs1;
   input [4:0]  rs2;   
   input [31:0] imm;
   begin
      BType(7'b1100011, rs1, rs2, imm, 3'b001);
   end
endtask

task BLT;
   input [4:0]  rs1;
   input [4:0]  rs2;   
   input [31:0] imm;
   begin
      BType(7'b1100011, rs1, rs2, imm, 3'b100);
   end
endtask

task BGE;
   input [4:0]  rs1;
   input [4:0]  rs2;   
   input [31:0] imm;
   begin
      BType(7'b1100011, rs1, rs2, imm, 3'b101);
   end
endtask

task BLTU;
   input [4:0]  rs1;
   input [4:0]  rs2;   
   input [31:0] imm;
   begin
      BType(7'b1100011, rs1, rs2, imm, 3'b110);
   end
endtask

task BGEU;
   input [4:0]  rs1;
   input [4:0]  rs2;   
   input [31:0] imm;
   begin
      BType(7'b1100011, rs1, rs2, imm, 3'b111);
   end
endtask
   
/***************************************************************************/   

/*
 * LUI and AUIPC
 */    

task UType;
   input [6:0]  opcode;
   input [4:0]  rd;
   input [31:0] imm;
   begin
      MEM[memPC[31:2]] = {imm[31:12], rd, opcode};
      memPC = memPC + 4;
   end
endtask

task LUI;
   input [4:0]  rd;
   input [31:0] imm;
   begin
      UType(7'b0110111, rd, imm);
   end
endtask

task AUIPC;
   input [4:0]  rd;
   input [31:0] imm;
   begin
      UType(7'b0010111, rd, imm);
   end
endtask
   
/***************************************************************************/   
   
/*
 * SYSTEM
 * (for now, just EBREAK)
 */

task EBREAK;
   begin
      MEM[memPC[31:2]] = {12'b000000000001, 5'b00000, 3'b000, 5'b00000, 7'b1110011};
      memPC = memPC + 4;
   end
endtask   
   
/***************************************************************************/   

/*
 * Labels.
 * Example of usage:
 *  
 *                   ADD(x1,x0,x0);
 *       Label(L0_); ADDI(x1,x1,1); 
 *                   JAL(x0, LabelRef(L0_));
 */

   integer L0_, L1_, L2_, L3_, L4_, L5_, L6_, L7_;

   task Label;
     output integer L;
     begin
	L = memPC;
     end
   endtask
   
   function [31:0] LabelRef;
     input integer L;
     begin
	$display("memPC=%d",memPC);
	$display("L=%d",L);	
	LabelRef = L - memPC;
	$display("LabelRef=%d",L - memPC);
     end
   endfunction
     
/****************************************************************************/
   
task SType;
   input [6:0]  opcode;
   input [4:0]  rs1;
   input [4:0]  rs2;   
   input [31:0] imm;
   input [2:0]  funct3;
   begin
      MEM[memPC[31:2]] = {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode};
      memPC = memPC + 4;
   end
endtask

