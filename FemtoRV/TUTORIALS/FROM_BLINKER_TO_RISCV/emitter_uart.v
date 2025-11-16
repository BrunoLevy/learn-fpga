module corescore_emitter_uart
  #(
    parameter clk_freq_hz = 0,
    parameter baud_rate = 115200)
  (
   input wire 	    i_clk,
   input wire 	    i_rst,
   input wire [7:0] i_data,
   input wire 	    i_valid,
   output reg 	    o_ready,
   output wire 	    o_uart_tx
);

   localparam START_VALUE = clk_freq_hz/baud_rate;
   
   localparam WIDTH = $clog2(START_VALUE);
   
   reg [WIDTH:0]  cnt = 0;
   
   reg [9:0] 	    data;

   assign o_uart_tx = data[0] | !(|data);

   always @(posedge i_clk) begin
      if (cnt[WIDTH] & !(|data)) begin
	 o_ready <= 1'b1;
      end else if (i_valid & o_ready) begin
	 o_ready <= 1'b0;
      end

      if (o_ready | cnt[WIDTH])
	cnt <= {1'b0,START_VALUE[WIDTH-1:0]};
      else
	cnt <= cnt-1;
      
      if (cnt[WIDTH])
	data <= {1'b0, data[9:1]};
      else if (i_valid & o_ready)
	data <= {1'b1, i_data, 1'b0};
   end

endmodule

