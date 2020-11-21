// See WaveShare doc, see also:
// https://github.com/adafruit/Adafruit-SSD1351-library/blob/master/Adafruit_SSD1351.cpp

/*****************************************************************/

// A simple timer (initialization needs two 0.5s delays)
module SSD1351Timer(
   input wire clk,
   input wire reset,
   output wire busy
);
  reg [23:0] cnt;
  assign busy = |cnt;
  always @(posedge clk) begin
     if(reset) begin
        cnt <= (1 << 23);
     end else if(busy) begin
        cnt <= cnt - 1;
     end
  end
endmodule

/*****************************************************************/

module SSD1351InitROM(
    input  wire [5:0] address,
    output reg  [8:0] data
);
   always @(*) begin
       case(address)
          0:  data=9'h0_02; // Reset low during 0.5s
	  1:  data=9'h0_01; // Reset high during 0.5s
	  2:  data=9'h0_fd; 3: data=9'h1_12; // Unlock driver
	  4:  data=9'h0_fd; 5: data=9'h1_b1; // unlock commands
	  6:  data=9'h0_ae; // display off
	  7:  data=9'h0_a4; // display mode off
	  8:  data=9'h0_15;  9: data=9'h1_00; 10: data=9'h1_7f; // column address
	  11: data=9'h0_75; 12: data=9'h1_00; 13: data=9'h1_7f; // row address
	  14: data=9'h0_b3; 15: data=9'h1_f1; // front clock divider (see section 8.5 of manual)
	  16: data=9'h0_ca; 17: data=9'h1_7f; // multiplex
	  18: data=9'h0_a0; 19: data=9'h1_74; // remap,data format,increment
	  20: data=9'h0_a1; 21: data=9'h1_00; // display start line
	  22: data=9'h0_a2; 23: data=9'h1_00; // display offset
	  24: data=9'h0_ab; 25: data=9'h1_01; // VDD regulator ON
	  26: data=9'h0_b4; 27: data=9'h1_a0; 28: data=9'h1_b5; 29: data=9'h1_55; // segment voltage ref pins
	  30: data=9'h0_c1; 31: data=9'h1_c8; 32: data=9'h1_80; 33: data=9'h1_c0; // contrast current for colors A,B,C
	  34: data=9'h0_c7; 35: data=9'h1_0f; // master contrast current
	  36: data=9'h0_b1; 37: data=9'h1_32; // length of segments 1 and 2 waveforms
	  38: data=9'h0_b2; 39: data=9'h1_a4; 40: data=9'h1_00; 41: data=9'h1_00; // display enhancement
	  42: data=9'h0_bb; 43: data=9'h1_17; // first pre-charge voltage phase 2
	  44: data=9'h0_b6; 45: data=9'h1_01; // second pre-charge period (see table 9-1 of manual)
	  46: data=9'h0_be; 47: data=9'h1_05; // Vcomh voltage
	  48: data=9'h0_a6; // display on // a6 = normal, a7 = inverse, a5 = all on
	  49: data=9'h0_af; // display mode on
          default: data=9'h0_00; // end of program
       endcase
   end

endmodule

/*****************************************************************/

// The driver for this nice 128x128x16M OLed display
// data: 9bits, first is DC (Data=1/Command=0)
// Pseudo-commands: h0_02: reset low duding 0.5s
//                  h0_01: reset high during 0.5s
//                  h0_00: end of program
module SSD1351(
   input wire clk,
   input wire wr, 
   input wire [8:0] data,
   output wire busy,
   output wire DIN, CLK, CS, DC, RST,
);

   // Divide internal frequency by 2 because
   // clock raising edges should be in the
   // middle of sent bits
   reg [3:0] divider; // Trying to divide by 16 instead of 2
   always @(posedge clk) begin
      divider <= divider + 1;
   end
   wire internal_clk = (divider[3] == 1'b0);
   wire send_clk     = (divider[3] == 1'b1);
   wire special      = (data[8:2] == 7'b0000000); // 1 if using one of the pseudo-commands
   
   // The timer for the two 0.5s initialization
   // steps.
   wire timer_busy;
   SSD1351Timer timer(
      .clk(internal_clk),
      .reset(wr && special && data[1:0] != 2'b00), // reset if pseudo-command and not END (all zero)
      .busy(timer_busy)
   );

   // Currently send bit, 1-based
   // (0000 config. corresponds to idle)
   reg[4:0] bitcount;
   reg[7:0] shifter;
   wire sending = |bitcount;
   
   assign busy = sending || timer_busy;
   
   assign DIN = shifter[7];
   assign CLK = sending && send_clk;
   assign CS  = special ? 1'b0 : !sending;
   assign DC  = data[8];
   assign RST = special ? data[0] : 1'b1;

   always @(posedge internal_clk)
   begin
       if(wr && !special) begin
          shifter <= data[7:0];
          bitcount <= 8;
       end else if(sending) begin
          bitcount <= bitcount - 4'd1;
          shifter <= {shifter[6:0], 1'b0};
       end
   end

endmodule

