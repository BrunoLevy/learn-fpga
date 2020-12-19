// femtorv32, a minimalistic RISC-V RV32I core
//    (minus SYSTEM and FENCE that are not implemented)
//
//       Bruno Levy, 2020-2021
//
// This file: driver for SSD1351 OLED display
//
// TODO: we could use wmask to write directly 16 bits or 32 bits of data

module SSD1351(
    input wire 	      clk,      // system clock
    input wire 	      wstrb,    // write strobe (use one of sel_xxx to select dest)
    input wire 	      sel_cntl, // wdata[0]: !CS;  wdata[1]: RST
    input wire 	      sel_cmd,  // send 8-bits command to display
    input wire 	      sel_dat,  // send 8-bits data to display

    input wire [31:0] wdata,    // data to be written

    output wire       wbusy,    // asserted if the driver is busy sending data

                           // SSD1351 pins	       
    output 	      DIN, // data in
    output 	      CLK, // clock
    output reg 	      CS,  // chip select (active low)
    output reg 	      DC,  // data (high) / command (low)
    output reg 	      RST  // reset (active low)
);
  
   initial begin
      DC  = 1'b0;
      RST = 1'b0;
      CS  = 1'b1;
   end

   /********* The clock ****************************************************/
   // Note: SSD1351 expects the raising edges of the clock in the middle of
   // the data bits.
   
 `ifdef BENCH // Seems that iverilog does not like this usage of generate.
   reg[1:0] slow_cnt;
   localparam cnt_bit = 1;
   localparam cnt_max = 2'b11;
 `else   
   generate
      if(`NRV_FREQ <= 60) begin
	 reg slow_cnt;
	 localparam cnt_bit = 0;
	 localparam cnt_max = 1'b1;
      end else begin
	 reg[1:0] slow_cnt;
	 localparam cnt_bit = 1;
	 localparam cnt_max = 2'b11;
      end
   endgenerate
 `endif

   always @(posedge clk) begin
      slow_cnt <= slow_cnt + 1;
   end

   assign CLK = slow_cnt[cnt_bit]; 
   
   /********* The shifter  **************************************************/
   
   // Currently sent bit, 1-based index
   // (0000 config. corresponds to idle)
   reg[3:0] bitcount = 4'b0000;
   reg[7:0] shifter = 0;
   wire     sending = (bitcount != 0);

   assign DIN = shifter[7];
   assign wbusy = sending;
   
   /*************************************************************************/
   
   always @(posedge clk) begin
      if(wstrb) begin
	 case(1'b1)
	   sel_cntl: begin
	      CS  <= !wdata[0];
	      RST <= wdata[1];
	   end
	   sel_cmd: begin
	      RST <= 1'b1;
	      DC <= 1'b0;
	      shifter <= wdata[7:0];
	      bitcount <= 8;
	      CS  <= 1'b1;
	   end
	   sel_dat: begin
 	      RST <= 1'b1;
	      DC <= 1'b1;
	      shifter <= wdata[7:0];
	      bitcount <= 8;
	      CS  <= 1'b1;
	   end
	 endcase
      end else begin 
	 if(slow_cnt == cnt_max) begin
	    if(sending) begin
	       if(CS) begin
		  CS <= 1'b0;
	       end else begin
		  bitcount <= bitcount - 4'd1;
		  shifter <= {shifter[6:0], 1'b0};
	       end
	    end else begin 
	       CS  <= 1'b1;  
	    end
	 end
      end
   end

endmodule
