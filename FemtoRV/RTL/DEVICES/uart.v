// femtorv32, a minimalistic RISC-V RV32I core
//
//       Bruno Levy, 2020-2021
//
// This file: driver for UART (serial over USB)

// Uncomment to use Claire Wolf's picosoc UART
// (eats up more LUTs, but more stable at high freq)

`define USE_CLAIRE_UART

`ifdef USE_CLAIRE_UART

`include "uart_picosoc_shrunk.v"

module UART(
    input wire 	       clk,      // system clock
    input wire 	       rstrb,    // read strobe		
    input wire 	       wstrb,    // write strobe
    input wire 	       sel_dat,  // select data reg (rw)
    input wire 	       sel_cntl, // select control reg (r) 	       	    
    input wire [31:0]  wdata,    // data to be written
    output wire [31:0] rdata,    // data read

    input wire 	       RXD, // UART pins
    output wire        TXD	    
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
   .resetq(1'b1),
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
   
endmodule

`else

// Use James Bowman's UART (smaller, but less stable at higher freqs)

`define CLKFREQ   (`NRV_FREQ*1000000) // Used by uart_impl.v (clk freq in Hz, NRV_FREQ is in MHz).
`include "uart_J1.v"                  // (uart_impl is borrowed from J1 swapforth)

module UART(
    input wire 	       clk,   // system clock
    input wire 	       rstrb, // read strobe		
    input wire 	       wstrb, // write strobe
    input wire 	       sel_dat,  // select data (rw)
    input wire         sel_cntl, // select control (r)
    input wire [31:0]  wdata, // data to be written
    output wire [31:0] rdata, // data read

    input wire 	       RXD, // UART pins
    output wire        TXD	    
);

//******************** UART Receiver ***************************

   reg serial_valid_latched = 1'b0;
   wire serial_valid;
   wire [7:0] serial_rx_data;
   reg  [7:0] serial_rx_data_latched;
   rxuart rxUART( 
       .clk(clk),
       .resetq(1'b1),       
       .uart_rx(RXD),
       .rd(1'b1),
       .valid(serial_valid),
       .data(serial_rx_data) 
   );

   always @(posedge clk) begin
      if(serial_valid) begin
         serial_rx_data_latched <= serial_rx_data;
	 serial_valid_latched <= 1'b1;
      end
      if(rstrb && sel_dat) begin
         serial_valid_latched <= 1'b0;
      end
   end

//******************** UART transmitter ***************************

   wire       serial_tx_busy;
   wire       serial_tx_wr;
   uart txUART(
       .clk(clk),
       .uart_tx(TXD),	       
       .resetq(1'b1),
       .uart_busy(serial_tx_busy),
       .uart_wr_i(serial_tx_wr),
       .uart_dat_i(wdata[7:0])		 
   );

   assign rdata =   sel_dat  ? {22'b0, serial_tx_busy, serial_valid_latched, serial_rx_data_latched}
                  : sel_cntl ? {22'b0, serial_tx_busy, serial_valid_latched, 8'b0   } 
                  : 32'b0;   

   assign serial_tx_wr = wstrb && sel_dat;

endmodule

`endif

