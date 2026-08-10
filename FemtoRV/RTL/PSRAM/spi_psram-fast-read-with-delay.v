/* SPI_PSRAM for learn-fpga based on file with following comment block*/
/* special case spi using fast read working at 30MHz will need to retest at higher clock*/
/* SIMPLIFY FURTHER*/
/*
 * QQSPI
 * Copyright (c) 2021 Lone Dynamics Corporation. All rights reserved.
 *
 * Verilog module for interfacing the LD-QQSPI-PSRAM32 Pmod(tm) compatible
 * module with ICE40 FPGAs.
 *
 */

`default_nettype none // for typo detection

module qspiram (
	input [19:0] word_addr,   //19:0 for word_address part [21:2] being fed in
	output reg [31:0] rdata,
	input [31:0] wdata,
         input [3:0] i_we, //femto
         output reg busy_w, //femto
         output reg busy_r, //femto
         input wire  stb_wr, //femto
         input  wire stb_rd, //femto
	input clk,
	input resetn,

	output reg ss,
	output reg sclk,
	output mosi,
	input miso

);
        reg [2:0] state;
	reg write;

	reg sio_do;
	wire sio_di;


	assign mosi = sio_do;

	assign sio_di = miso;


	localparam [2:0]
		STATE_IDLE			= 4'd0,
	//	STATE_INIT			= 4'd1, //state no longer needed as we are not bidirectional anymore
		STATE_START			= 4'd2,
		STATE_CMD			= 4'd3,
		STATE_ADDR			= 4'd4,
		STATE_WAIT			= 4'd5,
		STATE_XFER			= 4'd6,
		STATE_END			= 4'd7;

	reg [31:0] datbuf;
        reg [1:0]  offset;
        reg [5:0]  bwid; 

	reg [31:0] buffer;
	reg [5:0] xfer_bits;

	always @(posedge clk) begin

		if (!resetn) begin 

			ss <= 1;
			sclk <= 0;
			sio_do = 1'b0;

			xfer_bits <= 0;

			state <= STATE_IDLE;

		end else if (xfer_bits) begin

		        sio_do <= buffer[31];

			if (sclk) begin
				sclk <= 0;
			end else begin
				sclk <= 1;
				buffer <= {buffer, sio_di};
				xfer_bits <= xfer_bits - 1;
			end

		end else case (state)

			STATE_IDLE: begin
				ss <= 1;
              if (stb_rd) begin
                 write <= 0; 
                 busy_r <= 1;
                 state <= STATE_START;
                 xfer_bits <= 0;
                 offset <= 2'b00;
              end
              else if (stb_wr) begin
                 write <= 1; 
                 busy_w <= 1;
                 state <= STATE_START;
                 xfer_bits <= 0;
                case (i_we)
                4'b1000: begin
                  offset <= 2'b00;
                  bwid <= 8;
                  datbuf <= {wdata[31:24], 24'd0};
                end
                4'b0100: begin
                  offset <= 2'b01;
                  bwid <= 8;
                  datbuf <= {wdata[23:16], 24'd0};
                end
                4'b0010: begin
                  offset <= 2'b10;
                  bwid <= 8;
                  datbuf <= {wdata[15:8], 24'd0};
                end
                4'b0001: begin
                  offset <= 2'b11;
                  bwid <= 8;
                  datbuf <= {wdata[7:0], 24'd0};
                end
                4'b1100: begin
                  offset <= 2'b00;
                  bwid <= 16;
                  datbuf <= {wdata[31:16], 16'd0};
                end
                4'b0011: begin
                  offset <= 2'b10;
                  bwid <= 16;
                  datbuf <= {wdata[15:0], 16'd0};
                end
                4'b1111: begin
                  offset <= 2'b00;
                  bwid <= 32;
                  datbuf <= wdata;
                end
               //what about a default? which should never get hit anyway
                endcase
              end

			end

			STATE_START: begin
				ss <= 0;
				state <= STATE_CMD;
			end


			STATE_CMD: begin
				if (write) buffer[31:24] <= 8'h02; else buffer[31:24] <= 8'h0b;
				xfer_bits <= 8;
				state <= STATE_ADDR;
			end

			STATE_ADDR: begin
                                buffer[31:8] <= { 2'b00, word_addr[19:0], offset };
				xfer_bits <= 24;
				if (!write)                //will be needed if fast read mode used
					state <= STATE_WAIT;
				else
					state <= STATE_XFER;
			end

			STATE_WAIT: begin
				//xfer_bits <= 6; //delay for quad which we are not doing
				xfer_bits <= 8;   //assume fast read will be used in the future so get ready with relevant wait
				state <= STATE_XFER;
			end

			STATE_XFER: begin
				if (write) begin
					buffer <= datbuf;
				        xfer_bits <= bwid;
				end else begin
				        xfer_bits <= 32;
				end
				state <= STATE_END;
			end

			STATE_END: begin
				if (write)
					ss <= 1;
				else
					rdata <= buffer;
                                busy_r <= 0; // femto
                                busy_w <= 0; // femto
				state <= STATE_IDLE;
			end

		endcase

	end

endmodule
