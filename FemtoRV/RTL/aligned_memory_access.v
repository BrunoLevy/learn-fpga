/***** Adapter to read/write bytes,half words, words from/to memory ******/

/* 
 * Computes 32-bit aligned data to be written and write mask from 
 * input data, input data width and the two least significant bits of the addr
 */ 
module NrvStoreToMemory(
			input wire [31:0]  data,      // data to be written, from register
			input wire [1:0]   addr_LSBs, // the two LSBs of the memory address
			input wire [1:0]   width,     // 00:byte 01:half-word 10:word
			output reg [31:0] mem_wdata,  // realigned data to be sent to memory
			output reg [3:0]  mem_wstrb   // 4-bit write mask			
			);
   always @(*) begin   
      (* parallel_case, full_case *)   
      case(width)
	2'b00: begin
	   (* parallel_case, full_case *)            	   
	   case(addr_LSBs) 
	     2'b00: begin
		mem_wstrb = 4'b0001;
		mem_wdata = {24'bxxxxxxxxxxxxxxxxxxxxxxxx,data[7:0]};
	     end
	     2'b01: begin
		mem_wstrb = 4'b0010;
		mem_wdata = {16'bxxxxxxxxxxxxxxxx,data[7:0],8'bxxxxxxxx};
	     end
	     2'b10: begin
		mem_wstrb = 4'b0100;
		mem_wdata = {8'bxxxxxxxx,data[7:0],16'bxxxxxxxxxxxxxxxx};
	     end
	     2'b11: begin
		mem_wstrb = 4'b1000;
		mem_wdata = {data[7:0],24'bxxxxxxxxxxxxxxxxxxxxxxxx};
	     end
	   endcase
	end
	2'b01: begin
	   (* parallel_case, full_case *)            	   	   
	   case(addr_LSBs[1]) 
	     1'b0: begin
		mem_wstrb = 4'b0011;
		mem_wdata = {16'bxxxxxxxxxxxxxxxx,data[15:0]};
	     end
	     1'b1: begin
		mem_wstrb = 4'b1100;
		mem_wdata = {data[15:0],16'bxxxxxxxxxxxxxxxx};
	     end
	   endcase
	end 
	2'b10: begin
	   mem_wstrb = 4'b1111;
	   mem_wdata = data;
	end
	default: begin
	   mem_wstrb = 4'bxxxx;
	   mem_wdata = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
	end
      endcase 
   end
endmodule  

/*************************************************************************/

/*
 * Computes 32 bit data to be stored in a register from
 * raw memory data read from a 32-bit aligned address,
 * data width, sign expansion toggle, and the two
 * LSBs of the memory address.
 */ 
module NrvLoadFromMemory(
			 input wire [31:0]  mem_rdata,   // raw data read from memory
			 input wire [1:0]   addr_LSBs,   // the two LSBs of the memory address
			 input wire [1:0]   width,       // 00:byte 01:half-word 10:word
			 input wire 	    is_unsigned, // 0:do sign expansion 1:unsigned
			 output reg [31:0]  data         // the data to be sent to register
			 );

   reg [7:0]   mem_rdata_B;  // Extracted byte from mem_rdata
   reg [15:0]  mem_rdata_HW; // Extracted half-word from mem_rdata
   
   always @(*) begin
      (* parallel_case, full_case *)            
      case(addr_LSBs[1:0])
	2'b00: mem_rdata_B = mem_rdata[7:0];
	2'b01: mem_rdata_B = mem_rdata[15:8];
	2'b10: mem_rdata_B = mem_rdata[23:16];
	2'b11: mem_rdata_B = mem_rdata[31:24];
      endcase 

      (* parallel_case, full_case *)      
      case(addr_LSBs[1])
	1'b0: mem_rdata_HW = mem_rdata[15:0];
	1'b1: mem_rdata_HW = mem_rdata[31:16];
      endcase 

      (* parallel_case, full_case *)      
      case(width)
	2'b00:   data = {{24{is_unsigned?1'b0:mem_rdata_B[7]  }},mem_rdata_B };
	2'b01:   data = {{16{is_unsigned?1'b0:mem_rdata_HW[15]}},mem_rdata_HW};
	2'b10:   data = mem_rdata;
	default: data = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
      endcase
   end
   
endmodule

/*************************************************************************/

