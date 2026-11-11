`default_nettype none

module sram(
	input wire i_clk,
	input wire i_rst,
	output wire[17:0] o_sram_a,
	inout wire[15:0] io_sram_d,
	output wire o_sram_csn,
	output wire o_sram_oen,
	output wire o_sram_wen,

	input wire [19:0] i_addr,
	input wire [3:0] i_we,
	output wire [31:0] o_dat_r,
	input wire [31:0] i_dat_w,
	input wire i_stb,
	output reg o_ack
);
always @(posedge i_clk)
	if (i_rst | o_ack) o_ack <= 0;
	else if (mem_rstrb) o_ack <= 1;
	else if (mem_w2 & ~mem_w3) o_ack <= 1; 

wire mem_rstrb = i_stb & !(|i_we);
wire mem_wstrb = i_stb & (|i_we);

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

assign o_sram_csn = 0;
assign o_sram_wen = ~(mem_w1 | mem_w3);
assign o_sram_oen = ~(mem_rstrb | mem_r1 | mem_wstrb | mem_w2);
assign o_sram_a = {i_addr[16:0],mem_r1|mem_w2|mem_w3};

reg [15:0] data_out = 0;
always @(posedge i_clk)
	if (mem_wstrb)
		data_out <= {i_we[1]? i_dat_w[15:8]:io_sram_d[15:8],
					 i_we[0]? i_dat_w[ 7:0]:io_sram_d[ 7:0]};
	else if (mem_w2)
		data_out <= {i_we[3]? i_dat_w[31:24]:io_sram_d[15:8],
					 i_we[2]? i_dat_w[23:16]:io_sram_d[ 7:0]};
	
assign io_sram_d = ~o_sram_oen? 16'bzzzzzzzzzzzzzzzz : data_out;

assign o_dat_r = (mem_r1)? {io_sram_d,cache} : 32'd0;

reg [15:0] cache;
always @(posedge i_clk)
	if (mem_rstrb) cache <= io_sram_d;

endmodule
