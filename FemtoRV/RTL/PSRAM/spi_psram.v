/* SPI_PSRAM for learn-fpga based on file with following comment block*/
/* special case spi using fast read working at 30MHz will need to retest at higher clock*/
/* SIMPLIFY FURTHER*/
/*since we are clocking psram sclk at 1/2 clk use sclk 33MHz max read = slow read
which does not involve a wait of 8 clocks
if we want to go over clk = 66MHz will need to add wait state and switch read command to fast read
ideally if going that fast will have worked out problems with quad mode anyway*/
/*
 * QQSPI
 * Copyright (c) 2021 Lone Dynamics Corporation. All rights reserved.
 *
 * Verilog module for interfacing the LD-QQSPI-PSRAM32 Pmod(tm) compatible
 * module with ICE40 FPGAs.
 *
 */

//combine cmd and addr into one state

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
	inout mosi,
	inout miso,
	inout sio2,
	inout sio3

);
        reg [2:0] state;
	reg write;

	reg [3:0] sio_oe;
	reg [3:0] sio_do;
	wire [3:0] sio_di;


/*
	assign mosi = sio_oe[0] ? sio_do[0] : 1'bz;
	assign miso = sio_oe[1] ? sio_do[1] : 1'bz;
	assign sio2 = sio_oe[2] ? sio_do[2] : 1'bz;
	assign sio3 = sio_oe[3] ? sio_do[3] : 1'bz;

	assign sio_di = {sio3, sio2, miso, mosi};
*/

	SB_IO #(
		.PIN_TYPE(6'b1010_01),
		.PULLUP(1'b0)
	) qqspi_io [3:0] (
		.PACKAGE_PIN({sio3, sio2, miso, mosi}),
		.OUTPUT_ENABLE(sio_oe),
		.D_OUT_0(sio_do),
		.D_IN_0(sio_di)
	);

	localparam [2:0]
		STATE_IDLE			= 4'd0,
		STATE_INIT			= 4'd1,
		STATE_START			= 4'd2,
	//	STATE_CMD_AND_ADDR		= 4'd3,
		STATE_CMD			= 4'd3,
		STATE_ADDR			= 4'd4,
	//	STATE_WAIT			= 4'd5, //not needed for slow read
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
			sio_oe = 4'b1111;
			sio_do = 4'b0000;

			xfer_bits <= 0;

                        busy_r <= 0;
                        busy_w <= 0;

			state <= STATE_IDLE;

		end else if (xfer_bits) begin

		        sio_do[0] <= buffer[31];

			if (sclk) begin
				sclk <= 0;
			end else begin
				sclk <= 1;
				buffer <= {buffer, sio_di[1]};
				xfer_bits <= xfer_bits - 1;
			end

		end else case (state)
//could put a delay in here and possibly SWreset sequence

			STATE_IDLE: begin
				ss <= 1;
              if (stb_rd) begin
                 write <= 0; 
                 busy_r <= 1;
                 state <= STATE_INIT;
                 xfer_bits <= 0;
                 offset <= 2'b00;
              end
              else if (stb_wr) begin
                 write <= 1; 
                 busy_w <= 1;
                 state <= STATE_INIT;
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

			STATE_INIT: begin
				sio_oe <= 4'b0001;
				state <= STATE_START;
			end

			STATE_START: begin
				ss <= 0;
				state <= STATE_CMD;
			end

			STATE_CMD: begin
				//if (write) buffer[31:24] <= 8'h02; else buffer[31:24] <= 8'h0b;
				if (write) buffer[31:24] <= 8'h02; else buffer[31:24] <= 8'h03;

				xfer_bits <= 8;
				state <= STATE_ADDR;
			end

			STATE_ADDR: begin
                                buffer[31:8] <= { 2'b00, word_addr[19:0], offset };
				xfer_bits <= 24;
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
