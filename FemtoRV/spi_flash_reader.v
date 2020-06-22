/*
 * spi_flash_reader.v
 *
 * vim: ts=4 sw=4
 *
 * Copyright (C) 2019  Sylvain Munaut <tnt@246tNt.com>
 * All rights reserved.
 *
 * BSD 3-clause, see LICENSE.bsd
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the <organization> nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

`default_nettype none

module spi_flash_reader (
	// SPI interface
	output wire spi_mosi,
	input  wire spi_miso,
	output wire spi_cs_n,
	output wire spi_clk,

	// Command interface
	input  wire [23:0] addr,
	input  wire [15:0] len,
	input  wire go,
	output wire rdy,

	// Data interface
	output wire [7:0] data,
	output wire valid,

	// Clock / Reset
	input  wire clk,
	input  wire rst
);

	// Signals
	// -------

	// FSM
	localparam
		ST_IDLE 	= 0,
		ST_CMD		= 1,
		ST_DUMMY	= 2,
		ST_READ		= 3;

	reg [1:0] fsm_state;
	reg [1:0] fsm_state_next;

	// Counters
	reg [2:0] cnt_bit;
	reg cnt_bit_last;

	reg [ 1:0] cnt_cmd;
	wire cnt_cmd_last;

	reg [16:0] cnt_len;
	wire cnt_len_last;

	// Shift register
	reg [31:0] shift_reg;

	// Misc
	reg rdy_i;
	reg valid_i;

	// IOB control
	wire io_mosi;
	wire io_miso;
	wire io_cs_n;
	wire io_clk;


	// FSM
	// ---

	// State register
	always @(posedge clk or posedge rst)
		if (rst)
			fsm_state <= ST_IDLE;
		else
			fsm_state <= fsm_state_next;

	// Next-State logic
	always @(*)
	begin
		// Default is not to move
		fsm_state_next = fsm_state;

		// Transitions ?
		case (fsm_state)
			ST_IDLE:
				if (go)
					fsm_state_next = ST_CMD;

			ST_CMD:
				if (cnt_cmd_last & cnt_bit_last)
					fsm_state_next = ST_DUMMY;

			ST_DUMMY:
				if (cnt_bit_last)
					fsm_state_next = ST_READ;

			ST_READ:
				if (cnt_len_last & cnt_bit_last)
					fsm_state_next = ST_IDLE;
		endcase
	end


	// Shift Register
	// --------------

	always @(posedge clk or posedge rst)
		if (rst)
			shift_reg <= 32'hAB000000;
		else begin
			if (go)
				shift_reg <= { 8'h0B, addr };
			else
				shift_reg <= { shift_reg[30:0], io_miso };
		end


	// Counters
	// --------

	always @(posedge clk)
		if (go) begin
			cnt_bit <= 3'b000;
			cnt_bit_last <= 1'b0;
		end else if (fsm_state != ST_IDLE) begin
			cnt_bit <= cnt_bit + 1;
			cnt_bit_last <= (cnt_bit == 3'b110);
		end

	always @(posedge clk)
		if (go)
			cnt_cmd <= 2'b00;
		else if (fsm_state == ST_CMD)
			cnt_cmd <= cnt_cmd + cnt_bit_last;

	assign cnt_cmd_last = (cnt_cmd == 2'b11);

	always @(posedge clk)
		if (go)
			cnt_len <= { 1'b0, len } - 1;
		else if (fsm_state == ST_READ)
			cnt_len <= cnt_len - cnt_bit_last;

	assign cnt_len_last = cnt_len[16];


	// User IF
	// -------

	// Ready
	always @(posedge clk or posedge rst)
		if (rst)
			rdy_i <= 1'b0;
		else
			// This only raises rdy one cycle after we're back to IDLE to
			// leave time for the shift reg to push out the last read byte
			rdy_i <= (rdy_i | (fsm_state == ST_IDLE)) & ~go;

	assign rdy = rdy_i;

	// Data readout
	assign data = { shift_reg[6:0], io_miso };
	assign valid = valid_i;

	always @(posedge clk)
		valid_i <= (fsm_state == ST_READ) & cnt_bit_last;


	// IO control
	// ----------

	assign io_mosi = (fsm_state == ST_CMD) ? shift_reg[31] : 1'b0;
	assign io_cs_n = (fsm_state == ST_IDLE);
	assign io_clk  = (fsm_state != ST_IDLE);


	// IOBs
	// ----

	// MOSI output
		// Use DDR output to be half a cycle in advance
	SB_IO #(
		.PIN_TYPE(6'b010001),
		.PULLUP(1'b0),
		.NEG_TRIGGER(1'b0),
		.IO_STANDARD("SB_LVCMOS")
	) iob_mosi_I (
		.PACKAGE_PIN(spi_mosi),
		.CLOCK_ENABLE(1'b1),
		.OUTPUT_CLK(clk),
		.D_OUT_0(io_mosi),
		.D_OUT_1(io_mosi)
	);

	// MISO capture
		// Because SPI_CLK is aligned with out clock we can
		// use a simple register here to sample on rising SPI_CLK
	SB_IO #(
		.PIN_TYPE(6'b000000),
		.PULLUP(1'b0),
		.NEG_TRIGGER(1'b0),
		.IO_STANDARD("SB_LVCMOS")
	) iob_miso_I (
		.PACKAGE_PIN(spi_miso),
		.CLOCK_ENABLE(1'b1),
		.INPUT_CLK(clk),
		.D_IN_0(io_miso)
	);

	// Chip Select
		// Use DDR output to be half a cycle in advance
	SB_IO #(
		.PIN_TYPE(6'b010001),
		.PULLUP(1'b0),
		.NEG_TRIGGER(1'b0),
		.IO_STANDARD("SB_LVCMOS")
	) iob_cs_n_I (
		.PACKAGE_PIN(spi_cs_n),
		.CLOCK_ENABLE(1'b1),
		.OUTPUT_CLK(clk),
		.D_OUT_0(io_cs_n),
		.D_OUT_1(io_cs_n)
	);

	// Clock
		// Use DDR output to have rising edge of SPI_CLK with
		// the rising edge of our internal clock
	SB_IO #(
		.PIN_TYPE(6'b010001),
		.PULLUP(1'b0),
		.NEG_TRIGGER(1'b0),
		.IO_STANDARD("SB_LVCMOS")
	) iob_clk_I (
		.PACKAGE_PIN(spi_clk),
		.CLOCK_ENABLE(1'b1),
		.OUTPUT_CLK(clk),
		.D_OUT_0(io_clk),
		.D_OUT_1(1'b0)
	);

endmodule // spi_flash_reader
