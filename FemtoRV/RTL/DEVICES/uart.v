// femtorv32, a minimalistic RISC-V RV32I core
//
//       Bruno Levy, 2020-2021
//
// This file: driver for UART (serial over USB)
// Wrapper around modified Claire Wolf's UART

`ifdef BENCH

// If BENCH is define, using a fake UART that displays
// each sent character.
module UART(
    input wire 	       clk,      // system clock
    input wire 	       rstrb,    // read strobe		
    input wire 	       wstrb,    // write strobe
    input wire 	       sel_dat,  // select data reg (rw)
    input wire 	       sel_cntl, // select control reg (r) 	       	    
    input wire [31:0]  wdata,    // data to be written
    output wire [31:0] rdata,    // data read

    input wire 	       RXD, // UART pins (unused in bench mode)
    output wire        TXD,
	    
    output reg 	       brk  // goes high one cycle when <ctrl><C> is pressed. 	    
);
   assign rdata = 32'b0;
   assign TXD   = 1'b0;
   always @(posedge clk) begin
      if(sel_dat && wstrb) begin
	 if(wdata == 32'd4) begin
	    $display("<end of simulation> (EOT sent to UART)");
	    $finish();
	 end
         $write("%c",wdata[7:0]);
	 $fflush(32'h8000_0001);
      end
   end
endmodule

`else
// For some reasons, our 'compressed' version of
// the UART does not work on the ARTY, there is
// probably a couple of bugs there... 
`ifdef ARTY
`include "uart_picosoc.v.orig"
`else
`include "uart_picosoc_shrunk.v"
`endif

module UART(
    input wire 	       clk,      // system clock
    input wire 	       rstrb,    // read strobe		
    input wire 	       wstrb,    // write strobe
    input wire 	       sel_dat,  // select data reg (rw)
    input wire 	       sel_cntl, // select control reg (r) 	       	    
    input wire [31:0]  wdata,    // data to be written
    output wire [31:0] rdata,    // data read

    input wire 	       RXD, // UART pins
    output wire        TXD,

    output reg         brk  // goes high one cycle when <ctrl><C> is pressed. 	    
);

wire [7:0] rx_data;
wire [7:0] tx_data;
wire serial_tx_busy;
wire serial_valid;

buart #(
  .FREQ_MHZ(`NRV_FREQ),
  .BAUDS(115200)
) the_buart (
   .clk(clk),
   .resetq(!brk),
   .tx(TXD),
   .rx(RXD),
   .tx_data(wdata[7:0]),
   .rx_data(rx_data),
   .busy(serial_tx_busy),
   .valid(serial_valid),
   .wr(sel_dat && wstrb),
   .rd(sel_dat && rstrb) 
);

assign rdata =   sel_dat  ? {22'b0, serial_tx_busy, serial_valid, rx_data} 
               : sel_cntl ? {22'b0, serial_tx_busy, serial_valid, 8'b0   } 
               : 32'b0;   

always @(posedge clk) begin
   brk <= serial_valid && (rx_data == 8'd3);
end

endmodule
`endif
