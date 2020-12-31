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
 //                            removed reset logic
 //                            gained 20-30 LUTs

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

    parameter divider = FREQ_MHZ * 1000000 / BAUDS;

   /********************************** Receive ******************************/
   
    reg [7:0] recv_buf_data;
    reg recv_buf_valid;

    assign rx_data = recv_buf_data;
    assign valid = recv_buf_valid;
   
    reg [3:0] recv_state;
    reg [7:0] recv_pattern;

    // Counts to divider. Reserve enough bytes !   
    reg [$clog2(divider)-1:0] recv_divcnt;   
   
    wire recv_baudclk      = (recv_divcnt == divider + 1);
    wire recv_half_baudclk = recv_divcnt > divider/2;
    // If I replace with:
    // wire  recv_half_baudclk = (recv_divcnt == divider/2 + 1);
    // it saves additional LUTs, but sometimes received character 
    // is garbage (and I do not understand why, because I think
    // it is equivalent).
   
    always @(posedge clk) begin
       recv_divcnt <= recv_divcnt + 1;
       
       if (rd) recv_buf_valid <= 0;

       case (recv_state)
         0: begin
            if (!rx)
              recv_state <= 1;
         end
         1: begin
            if (recv_half_baudclk) begin
               recv_state <= 2;
               recv_divcnt <= 0;
            end
         end
         10: begin
            if (recv_baudclk) begin
               recv_buf_data <= recv_pattern;
               recv_buf_valid <= 1;
               recv_state <= 0;
            end
         end
         default: begin
            if (recv_baudclk) begin
               recv_pattern <= {rx, recv_pattern[7:1]};
               recv_state <= recv_state + 1;
               recv_divcnt <= 0;
            end
         end
       endcase
    end

   /********************************** Send *********************************/
   
    reg [9:0] send_pattern;
    reg [3:0] send_bitcnt;

    assign tx = send_pattern[0];
    assign busy = (send_bitcnt != 0);

    // Counts to divider. Reserve enough bytes !   
    reg [$clog2(divider)-1:0] send_divcnt;   
    wire send_baudclk = (send_divcnt == divider + 1);

    always @(posedge clk) begin
       send_divcnt <= send_divcnt + 1;
       if (wr && !send_bitcnt) begin
          send_pattern <= {1'b1, tx_data[7:0], 1'b0};
          send_bitcnt <= 10;
          send_divcnt <= 0;
       end else if ((send_divcnt == divider + 1) && (send_bitcnt != 0)) begin
          send_pattern <= {1'b1, send_pattern[9:1]};
          send_bitcnt <= send_bitcnt - 1;
          send_divcnt <= 0;
       end
    end

endmodule


