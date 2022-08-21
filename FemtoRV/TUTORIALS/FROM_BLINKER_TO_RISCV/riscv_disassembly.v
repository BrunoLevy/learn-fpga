/*
 * A simple disassembler for RiscV written in VERILOG.
 * See table page 104 of RiscV instruction manual.
 * Bruno Levy, August 2022
 */

function signed [31:0] riscv_disasm_Iimm;
  input [31:0] instr;
  riscv_disasm_Iimm = {{21{instr[31]}}, instr[30:20]};
endfunction

function signed [31:0] riscv_disasm_Simm;
  input [31:0] instr;
  riscv_disasm_Simm = {{21{instr[31]}}, instr[30:25],instr[11:7]};
endfunction

function [19:0] riscv_disasm_Uimm_raw;
  input [31:0] instr;
  riscv_disasm_Uimm_raw = {instr[31:12]};
endfunction

function [31:0] riscv_disasm_Uimm;
  input [31:0] instr;
  riscv_disasm_Uimm = {instr[31],instr[30:12],{12{1'b0}}};
endfunction

function [31:0] riscv_disasm_Bimm;
  input [31:0] instr;
  riscv_disasm_Bimm = {
	  {20{instr[31]}},instr[7],instr[30:25],instr[11:8],1'b0
  };
endfunction

function [31:0] riscv_disasm_Jimm;
  input [31:0] instr;
  riscv_disasm_Jimm = {
          {12{instr[31]}},instr[19:12],instr[20],instr[30:21],1'b0
  };
endfunction

task riscv_disasm;
   input [31:0] instr;
   input [31:0] PC;   
   begin
      case(instr[6:0])
	7'b0110011: begin
	   if(instr[31:7] == 0) begin
	     $write("nop");
	   end else begin
	      case(instr[14:12])
		3'b000: $write("%s", instr[30] ? "sub" : "add");
		3'b001: $write("sll");
		3'b010: $write("slt");
		3'b011: $write("sltu");
		3'b100: $write("xor");
		3'b101: $write("%s", instr[30] ? "sra" : "srl");
		3'b110: $write("or");
		3'b111: $write("and");
	      endcase 
	      $write(" x%0d,x%0d,x%0d",instr[11:7],instr[19:15],instr[24:20]);
	   end
	end
	7'b0010011: begin
	   case(instr[14:12])
	     3'b000: $write("addi");
	     3'b010: $write("slti");
	     3'b011: $write("sltiu");
	     3'b100: $write("xori");
	     3'b110: $write("ori");
	     3'b111: $write("andi");
	     3'b001: $write("slli");
	     3'b101: $write("%s", instr[30] ? "srai" : "srli");
	   endcase
	   if(instr[14:12] == 3'b001 || instr[14:12] == 3'b101) begin
	      $write(" x%0d,x%0d,%0d",
		     instr[11:7],instr[19:15],instr[24:20]
	      );
	   end else begin
	      $write(" x%0d,x%0d,%0d",
		     instr[11:7],instr[19:15],riscv_disasm_Iimm(instr)
	      );
	   end
	end
	7'b1100011: begin
	   case(instr[14:12])
	     3'b000: $write("beq");
	     3'b001: $write("bne");
	     3'b100: $write("blt");
	     3'b101: $write("bge");
	     3'b110: $write("bltu");
	     3'b111: $write("bgeu");
	     default: $write("B???");
	   endcase 
  	   $write(" x%0d,x%0d,0x%0h",
		  instr[19:15],instr[24:20],PC+riscv_disasm_Bimm(instr)
	   );
	end
	7'b1100111:
	  $write("jalr x%0d,x%0d,%0d",
		 instr[11:7],instr[19:15],riscv_disasm_Iimm(instr)
	  );
	7'b1101111:
	  $write("jal x%0d,0x%0h",instr[11:7],PC+riscv_disasm_Jimm(instr));
	7'b0010111:
	  $write("auipc x%0d,0x%0h <0x%0h>",
		 instr[11:7],
		 riscv_disasm_Uimm_raw(instr),PC+riscv_disasm_Uimm(instr)
	  );	  	  	  	  
	7'b0110111:
	  $write("lui x%0d,0x%0h <0x%0h>",
		 instr[11:7],
		 riscv_disasm_Uimm_raw(instr),riscv_disasm_Uimm(instr)
          );	  
	7'b0000011: begin
	   case(instr[14:12])
	     3'b000: $write("lb");
	     3'b001: $write("lh");
	     3'b010: $write("lw");
	     3'b100: $write("lbu");
	     3'b101: $write("lhu");
	     default: $write("l??");
	   endcase 
	   $write(" x%0d,%0d(x%0d)",
		  instr[11:7],riscv_disasm_Iimm(instr),instr[19:15]
           );
	end
	7'b0100011: begin
	   case(instr[14:12])
	     3'b000: $write("sb");
	     3'b001: $write("sh");
	     3'b010: $write("sw");
	     default: $write("s??");
	   endcase 
	   $write(" x%0d,%0d(x%0d)",
		  instr[24:20],riscv_disasm_Simm(instr),instr[19:15]
	   );
	end
	7'b1110011: begin
	   case(instr[14:12])
	     3'b000: $write("ebreak");
	     3'b010: begin
		case({instr[27],instr[21]})
		  2'b00: $write("rdcycle x%0d",   instr[11:7]);
		  2'b10: $write("rdcycleh x%0d",  instr[11:7]);
		  2'b01: $write("rdinstret x%0d", instr[11:7]);
		  2'b11: $write("rdinstreth x%0d",instr[11:7]);
		endcase
	     end
	     default: $write("SYSTEM");
	   endcase
	end
	default:
	  $write("?????");
      endcase
   end
endtask

