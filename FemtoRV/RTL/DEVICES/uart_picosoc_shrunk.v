/*
 *  PicoSoC - A simple example SoC using PicoRV32
 *
 *  Copyright (C) 2017  Clifford Wolf <clifford@clifford.at>
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */

 // October 2019, Matthias Koch: Renamed wires
 // December 2020, Bruno Levy: parameterization with freq and bauds
 //                            Factorized recv_divcnt and send_divcnt
 //                            Additional LUT golfing tricks
 
module buart #(
  parameter FREQ_MHZ = 60,
  parameter BAUDS    = 115200	       
) (
    input clk,
    input resetq,

    output tx,
    input  rx,

    input  wr,
    input  rd,
    input  [7:0] tx_data,
    output [7:0] rx_data,

    output busy,
    output valid
);

   /************** Baud frequency generator *******************/
   
    // Generates the bauds clock, and the 
    // half-cycle for the receiver.
    parameter divider = FREQ_MHZ * 1000000 / BAUDS;
    parameter divwidth = $clog2(divider);
   
    /* verilator lint_off WIDTH */
    parameter [divwidth:0] baud_init = divider;
    parameter [divwidth:0] half_baud_init = divider/2+1; 
    /* verilator lint_on WIDTH */
   
    // Trick from Olof Kindgren: use n+1 bit and decrement instead of
    // incrementing, and test the sign bit.
    reg [divwidth:0] divcnt; 
    wire baud_clk  = divcnt[divwidth];
    always @(posedge clk) begin
       if((recv_state == 0) && !rx) begin
           // half period for the first received bit
          divcnt <= half_baud_init;
       end else if(  
           (wr && (send_bitcnt == 0)) || baud_clk 
       ) begin
          divcnt <= baud_init;
       end else begin
	  divcnt <= divcnt - 1;
       end
    end   

   /************* Receiver ***********************************/
   
    reg [3:0] recv_state;
    reg [7:0] recv_pattern;
    reg [7:0] recv_buf_data;
    reg recv_buf_valid;

    assign rx_data = recv_buf_data;
    assign valid = recv_buf_valid;

    always @(posedge clk) begin

       if (rd) begin
	  recv_buf_valid <= 0;
       end

       case (recv_state)
         0: begin
            if (!rx) begin
               recv_state <= 1;
	    end
         end
         1: begin
	    // This one is triggered after a half-period
	    // (state 0 initializes the counter with divider/2+1)
            if (baud_clk) begin 
               recv_state <= 2;
            end
         end
         10: begin
            if (baud_clk) begin
               recv_buf_data <= recv_pattern;
               recv_buf_valid <= 1;
               recv_state <= 0;
            end
         end
         default: begin
            if (baud_clk) begin
               recv_pattern <= {rx, recv_pattern[7:1]};
               recv_state <= recv_state + 1;
            end
         end
       endcase
    end

   /************* Transmitter ******************************/
   
    reg [9:0] send_pattern = 1;
    reg [3:0] send_bitcnt;
    assign busy = |send_bitcnt;
    assign tx = send_pattern[0];

    always @(posedge clk) begin
       if (wr && !busy) begin
          send_pattern <= {1'b1, tx_data[7:0], 1'b0};
          send_bitcnt <= 10;
       end else if (baud_clk && busy) begin
          send_pattern <= {1'b1, send_pattern[9:1]};
          send_bitcnt <= send_bitcnt - 1;
       end
    end

endmodule


