//this has been proven on trenz icezero rev 02
//I had 2 boards
//caution I may have blown up a brand new board by connecting to pi5
//this was a comletely new untouched icezero so maybe it had a fault
//but in future I will stick to piz2w for host to trenz icezero pi hat 

//trenz icezero rev 03 boards are supposed to be available from
//early Feb 2026

// based on information from 2 sources
// http://www.clifford.at/icestorm/
// git clone https://github.com/cliffordwolf/icotools.git
// see icotools/examples/icezero/icezero.v etc for sram interface on 
// trenz icezero
// git clone https://github.com/x653/xv6-riscv-fpga.git 
//
// see xv6-riscv-fpga/fpga/sram.v


//pin o_sram_a[18] is NC at the chip on standard boards
//there may be a possibility you could upgrade from 512K to 1MB SRAM if
//you order a custom product or replace the 512K part with a 1MB part yourself 

//10ns 512K is expected
//but if your really lucky you may have 10ns 1MB
//I've also noticed at some earlier point 45ns SRAM was being fitted
//but my tests were with 10ns SRAM

//tested at 32MHz and 45MHz with femtorv32_quark_sram.v


`default_nettype none

module sram(
	input wire i_clk,
	input wire i_rst,
	output wire[18:0] o_sram_a,
	inout wire[15:0] io_sram_d,
// 	output wire o_sram_csn,
// 	output wire o_sram_ub_l,
// 	output wire o_sram_lb_l,
	output wire o_sram_oen,
	output wire o_sram_wen,

	input wire [17:0] i_addr,
	input wire [3:0] i_we,
	output wire [31:0] o_dat_r,
	input wire [31:0] i_dat_w,
		
	input wire i_strb_r,
	input wire i_strb_w,
	output wire o_busy_r,
	output wire o_busy_w
);

//one hot bit pattern supposed to save resources
//but not trying
   localparam SRAM_S0  = 0;
   localparam SRAM_S1  = 1;
   localparam SRAM_S2  = 2;
   localparam SRAM_S3  = 3; 

reg stb = 0;
reg [1:0]sram_state = SRAM_S0;


reg busy_r = 0;
reg busy_w = 0;
assign o_busy_r = busy_r;
assign o_busy_w = busy_w;

reg [3:0]i_we_latch = 0;
wire [3:0]i_we_wire = i_we[3:0];

always @(posedge i_clk) begin
    if (!i_rst) begin
	   sram_state <= SRAM_S0;
	   busy_r <= 0;
	   busy_w <= 0;
	   stb <= 0;
    end
    else
    case(sram_state)
	   SRAM_S0: begin	      
	      if (i_strb_r ^ i_strb_w) begin
	         if (i_strb_r) busy_r <= 1;
	         if (i_strb_w) busy_w <= 1;
		     i_we_latch <= i_we_wire;  //latch
	         stb <= 1;
	         sram_state <= SRAM_S1;	      
	      end 
	      else begin
	         busy_r <= 0;
	         busy_w <= 0;
		     i_we_latch <= 4'b0000;
	         stb <= 0;
	         sram_state <= SRAM_S0;
	      end
	   end	 
	   SRAM_S1: begin
	      stb <= 0;
	      if (busy_r) begin 
	          busy_r <= 0;
		      sram_state <= SRAM_S0;
	      end
	      else  
              sram_state <= SRAM_S2;
	   end
	   SRAM_S2: begin              	   
	          sram_state <= SRAM_S3;
           end
	   SRAM_S3: begin
	      busy_w <= 0;
	      sram_state <= SRAM_S0;
	   end	   
    endcase     	
end
    
wire mem_rstrb = stb & !(|i_we_latch);
wire mem_wstrb = stb & (|i_we_latch);

reg mem_r1 = 0;
always @(posedge i_clk) begin
		mem_r1 <= mem_rstrb & ~mem_r1;
end

reg mem_w1=0;
always @(posedge i_clk) begin
		mem_w1 <= mem_wstrb & ~mem_w1;
end

reg mem_w2=0;
always @(posedge i_clk) begin
		mem_w2 <= mem_w1 & ~mem_w2;
end
reg mem_w3=0;
always @(posedge i_clk) begin
		mem_w3 <= mem_w2 & ~mem_w3;
end

//assign o_sram_csn = 1'b0;
//assign o_sram_lb_l = 1'b0;
//assign o_sram_ub_l = 1'b0;

assign o_sram_wen = ~(mem_w1 | mem_w3);
assign o_sram_oen = ~(mem_rstrb | mem_r1 | mem_wstrb | mem_w2);
assign o_sram_a = {i_addr[17:0],mem_r1|mem_w2|mem_w3};

reg [15:0] data_out = 0;
always @(posedge i_clk)
	if (mem_wstrb)
		data_out <= {i_we_latch[1] ? i_dat_w[15:8] : io_sram_d[15:8],
					 i_we_latch[0] ? i_dat_w[ 7:0] : io_sram_d[ 7:0]};
	else if (mem_w2)
		data_out <= {i_we_latch[3] ? i_dat_w[31:24] : io_sram_d[15:8],
					 i_we_latch[2] ? i_dat_w[23:16] : io_sram_d[ 7:0]};
	
assign io_sram_d = ~o_sram_oen ? 16'bzzzzzzzzzzzzzzzz : data_out;

assign o_dat_r = (mem_r1) ? {io_sram_d,cache} : 32'd0;

reg [15:0] cache;
always @(posedge i_clk)
	if (mem_rstrb) cache <= io_sram_d;

endmodule
