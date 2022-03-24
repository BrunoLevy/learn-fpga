
/*
 * Clockworks includes
 *   - gearbox to divide clock frequency, used
 *     to let you observe how the design behaves
 *     one cycle at a time.
 *   - reset mechanism that resets the design
 *     during the first microseconds because
 *     reading in Ice40 BRAM during the first 
 *     few microseconds returns garbage !
 *     (made me bang my head against the wall). 
 * 
 * Parameters
 *     SLOW number of bits of gearbox. Clock divider
 *       is (1 << SLOW)
 * 
 * Macros
 *     NEGATIVE_RESET if board's RESET pin goes low on reset
 *     ICE_STICK if board is an IceStick.
 */     
module Clockworks 
(
   input  CLK, // clock pin of the board
   input  RESET, // reset pin of the board
   output clk,   // (optionally divided) clock for the design.
                 // divided if SLOW is different from zero.
   output resetn // (optionally timed) negative reset for the design
);               
   parameter SLOW=0;

   generate

/****************************************************

 Slow speed mode.
 - Create a clock divider to let observe what happens.
 - Nothing special to do for reset
 
 ****************************************************/
      if(SLOW != 0) begin
	 // Factor is 1 << slow_bit.
	 // Since simulation is approx. 16 times slower than
	 // actual device we use different factor for bosh.
`ifdef BENCH
   localparam slow_bit=SLOW-4;
`else
   localparam slow_bit=SLOW;
`endif
	 reg [slow_bit:0] slow_CLK = 0;
	 always @(posedge CLK) begin
	    slow_CLK <= slow_CLK + 1;
	 end
	 assign clk = slow_CLK[slow_bit];

`ifdef NEGATIVE_RESET
	 assign resetn = RESET;
`else
	 assign resetn = !RESET;
`endif


/****************************************************

 High speed mode.
 - Nothing special to do for the clock
 - A timer that resets the design during the first
   few microseconds, because reading in Ice40 BRAM 
   during the first few microseconds returns garbage !
   (made me bang my head against the wall).
 
 ****************************************************/
	 
      end else begin 
	 
	 assign clk = CLK;

// Preserve resources on Ice40HX1K (IceStick) with 
// carefully tuned counter (12 bits suffice). 
// For other FPGAs, use larger counter.
`ifdef ICE_STICK
	 reg [11:0] 	    reset_cnt = 0;
`else   
	 reg [15:0] 	    reset_cnt = 0;
`endif   
	 assign resetn = &reset_cnt;

`ifdef NEGATIVE_RESET
	 always @(posedge CLK,negedge RESET) begin
	    if(!RESET) begin
	       reset_cnt <= 0;
	    end else begin
	       reset_cnt <= reset_cnt + !resetn;
	    end
	 end
`else   
	 always @(posedge CLK,posedge RESET) begin
	    if(RESET) begin
	       reset_cnt <= 0;
	    end else begin
	       reset_cnt <= reset_cnt + !resetn;
	    end
	 end
`endif   
      end
   endgenerate

endmodule
