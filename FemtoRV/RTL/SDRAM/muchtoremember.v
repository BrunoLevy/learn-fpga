
// SDRAM interface to AS4C32M16SB-7TCN
// 512 Mbit Single-Data-Rate SDRAM, 32Mx16 (8M x 16 x 4 Banks)

// Matthias Koch, January 2022

// With a lot of inspiration from Mike Field, Hamsterworks:

// https://web.archive.org/web/20190215130043/http://hamsterworks.co.nz/mediawiki/index.php/Simple_SDRAM_Controller
// https://web.archive.org/web/20190215130043/http://hamsterworks.co.nz/mediawiki/index.php/File:Verilog_Memory_controller_v0.1.zip

// Note: You may need to change all values marked with *** when changing clock frequency. This is for 40 MHz.

module muchtoremember (

  // Interface to SDRAM chip, fully registered

  output             sd_clk,        // Clock for SDRAM chip
  output reg         sd_cke,        // Clock enabled
  inout      [15:0]  sd_d,          // Bidirectional data lines to/from SDRAM
  output reg [12:0]  sd_addr,       // Address bus, multiplexed, 13 bits
  output reg  [1:0]  sd_ba,         // Bank select wires for 4 banks
  output reg  [1:0]  sd_dqm,        // Byte mask
  output reg         sd_cs,         // Chip select
  output reg         sd_we,         // Write enable
  output reg         sd_ras,        // Row address select
  output reg         sd_cas,        // Columns address select

  // Interface to processor

  input  clk,
  input  resetn,
  input  [3:0] wmask,
  input  rd,
  input  [25:0] addr,
  input  [31:0] din,
  output reg [31:0] dout,
  output reg busy
);

  parameter sdram_startup_cycles = 10100; // *** -- 100us, plus a little more, @ 100MHz
  parameter sdram_refresh_cycles = 195;  // *** The refresh operation must be performed 8192 times within 64ms. --> One refresh every 7.8125 us.
                                        // With a minimum clock of 25 MHz, this results in one refresh every 7.8125e-6 * 25e6 = 195 cycles.

  // ----------------------------------------------------------
  // -- Connections and buffer primitives
  // ----------------------------------------------------------

  assign sd_clk = ~clk;   // Supply memory chip with a clock.

  wire [15:0] sd_data_in;     // Bidirectional data from SDRAM
  reg  [15:0] sd_data_out;    // Bidirectional data to   SDRAM
  reg         sd_data_drive;  // High: FPGA controls wires Low: SDRAM controls wires


  `ifdef __ICARUS__

  reg [15:0] sd_data_in_buffered;
  assign sd_d = sd_data_drive ? sd_data_out : 16'bz;
  always @(posedge clk) sd_data_in_buffered <= sd_d;
  assign sd_data_in = sd_data_in_buffered;

  `else

  wire [15:0] sd_data_in_unbuffered;  // To connect primitives internally

  TRELLIS_IO #(.DIR("BIDIR"))
  sdio_tristate[15:0] (
    .B(sd_d),
    .I(sd_data_out),
    .O(sd_data_in_unbuffered),
    .T(!sd_data_drive)
  );

  // Registering the input is important for stability and delays data arrival by one clock cycle.
  IFS1P3BX dbi_ff[15:0] (.D(sd_data_in_unbuffered), .Q(sd_data_in), .SCLK(clk),  .PD({16{sd_data_drive}}));

  `endif
  // ----------------------------------------------------------
  // -- Configuration to initialise the SDRAM chip
  // ----------------------------------------------------------

  // Taken from https://github.com/rxrbln/picorv32/blob/master/picosoc/sdram.v

  localparam NO_WRITE_BURST = 1'b0;   // 0=write burst enabled, 1=only single access write
  localparam OP_MODE        = 2'b00;  // only 00 (standard operation) allowed
  localparam CAS_LATENCY    = 3'd2;   // 2 or 3 cycles allowed
  localparam ACCESS_TYPE    = 1'b0;   // 0=sequential, 1=interleaved
  localparam BURST_LENGTH   = 3'b001; // 000=1, 001=2, 010=4, 011=8

  localparam MODE = {3'b000, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_LENGTH};

  // ----------------------------------------------------------
  // -- All possible commands for the SDRAM chip
  // ----------------------------------------------------------

  //                           CS, RAS, CAS, WE
  localparam CMD_INHIBIT         = 4'b1111;

  localparam CMD_NOP             = 4'b0111;
  localparam CMD_BURST_TERMINATE = 4'b0110;
  localparam CMD_READ            = 4'b0101;
  localparam CMD_WRITE           = 4'b0100;
  localparam CMD_ACTIVE          = 4'b0011;
  localparam CMD_PRECHARGE       = 4'b0010;
  localparam CMD_AUTO_REFRESH    = 4'b0001;
  localparam CMD_LOAD_MODE       = 4'b0000;

  // ----------------------------------------------------------
  // -- States of the SDRAM controller
  // ----------------------------------------------------------

  localparam s_init_bit      = 0;  localparam s_init      = 1 << s_init_bit      ;
  localparam s_idle_bit      = 1;  localparam s_idle      = 1 << s_idle_bit      ;
  localparam s_activate_bit  = 2;  localparam s_activate  = 1 << s_activate_bit  ;
  localparam s_read_1_bit    = 3;  localparam s_read_1    = 1 << s_read_1_bit    ;
  localparam s_read_2_bit    = 4;  localparam s_read_2    = 1 << s_read_2_bit    ;
  localparam s_read_3_bit    = 5;  localparam s_read_3    = 1 << s_read_3_bit    ;
  localparam s_read_4_bit    = 6;  localparam s_read_4    = 1 << s_read_4_bit    ;
  localparam s_read_5_bit    = 7;  localparam s_read_5    = 1 << s_read_5_bit    ;
  localparam s_write_1_bit   = 8;  localparam s_write_1   = 1 << s_write_1_bit   ;
  localparam s_write_2_bit   = 9;  localparam s_write_2   = 1 << s_write_2_bit   ;

  localparam s_idle_in_6_bit = 10; localparam s_idle_in_6 = 1 << s_idle_in_6_bit ;
  localparam s_idle_in_5_bit = 11; localparam s_idle_in_5 = 1 << s_idle_in_5_bit ;
  localparam s_idle_in_4_bit = 12; localparam s_idle_in_4 = 1 << s_idle_in_4_bit ;
  localparam s_idle_in_3_bit = 13; localparam s_idle_in_3 = 1 << s_idle_in_3_bit ;
  localparam s_idle_in_2_bit = 14; localparam s_idle_in_2 = 1 << s_idle_in_2_bit ;
  localparam s_idle_in_1_bit = 15; localparam s_idle_in_1 = 1 << s_idle_in_1_bit ;

  (* onehot *)
  reg [15:0] state = s_init;

  // ----------------------------------------------------------
  // -- Access control wires
  // ----------------------------------------------------------

  reg [14:0] reset_counter = sdram_startup_cycles;
  reg  [7:0] refresh_counter = 0;
  reg        refresh_pending = 1;
  reg           rd_sticky  = 0;
  reg  [3:0] wmask_sticky  = 4'b0000;

  wire stillatwork = ~(state[s_read_5_bit] | state[s_write_2_bit]);
  wire [8:0] refresh_counterN = refresh_counter - 1;

  // ----------------------------------------------------------
  // -- The memory controller
  // ----------------------------------------------------------

  always @(posedge clk)
    if(!resetn) begin
      state         <= s_init;
      reset_counter <= sdram_startup_cycles; // Counts backwards to zero
      busy          <= 0;  // Technically, we are busy with initialisation, but there are no ongoing read or write requests
      rd_sticky     <= 0;
      wmask_sticky  <= 4'b0000;
      sd_cke        <= 0;
    end else begin

      // FemtoRV32 pulses read and write lines high for exactly one clock cycle.
      // Address and data lines keep stable until busy is released.
      // Therefore: Take note of the requested read or write, and assert busy flag immediately.

         busy      <= ((|wmask) | rd) | (busy         &    stillatwork   );
         rd_sticky <=             rd  | (rd_sticky    &    stillatwork   );
      wmask_sticky <=    wmask        | (wmask_sticky & {4{stillatwork}} );

      // Schedule refreshes regularly
      refresh_counter <= refresh_counterN[8] ? sdram_refresh_cycles : refresh_counterN[7:0];
      refresh_pending <= (refresh_pending & ~state[s_idle_bit]) | refresh_counterN[8];

      (* parallel_case *)
      case(1'b1)

        // Processor can already request the first read or write here, but has to wait then:

        state[s_init_bit]: begin

          //------------------------------------------------------------------------
          //-- This is the initial startup state, where we wait for at least 100us
          //-- before starting the start sequence
          //--
          //-- The initialisation is sequence is
          //--  * de-assert SDRAM_CKE
          //--  * 100us wait,
          //--  * assert SDRAM_CKE
          //--  * wait at least one cycle,
          //--  * PRECHARGE
          //--  * wait 2 cycles
          //--  * REFRESH,
          //--  * tREF wait
          //--  * REFRESH,
          //--  * tREF wait
          //--  * LOAD_MODE_REG
          //--  * 2 cycles wait
          //------------------------------------------------------------------------

          sd_ba  <= 2'b00;    // Reserved for future use in mode configuration
          sd_dqm <= 2'b11;    // Data bus in High-Z state
          sd_data_drive <= 0; // Do not drive the data bus now

          case (reset_counter) // Counts from a large value down to zero

            33: begin sd_cke <= 1; end

            // Ensure all rows are closed
            31: begin {sd_cs, sd_ras, sd_cas, sd_we} <= CMD_PRECHARGE; sd_addr <= 13'b0010000000000; end

            // These refreshes need to be at least tRFC (63ns) apart
            23: begin {sd_cs, sd_ras, sd_cas, sd_we} <= CMD_AUTO_REFRESH; end
            15: begin {sd_cs, sd_ras, sd_cas, sd_we} <= CMD_AUTO_REFRESH; end

            // Now load the mode register
            7:  begin {sd_cs, sd_ras, sd_cas, sd_we} <= CMD_LOAD_MODE; sd_addr <= MODE; end

            default:  {sd_cs, sd_ras, sd_cas, sd_we} <= CMD_NOP;
          endcase

          reset_counter <= reset_counter - 1;
          if (reset_counter == 0) state <= s_idle;
        end

        // New read or write requests from the processor may arrive in these states:

        //-----------------------------------------------------
        //-- Additional NOPs to meet timing requirements
        //-----------------------------------------------------

        state[s_idle_in_6_bit]: begin state <= s_idle_in_5;  {sd_cs, sd_ras, sd_cas, sd_we} <= CMD_NOP; end
        state[s_idle_in_5_bit]: begin state <= s_idle_in_4;  {sd_cs, sd_ras, sd_cas, sd_we} <= CMD_NOP; end
        state[s_idle_in_4_bit]: begin state <= s_idle_in_3;  {sd_cs, sd_ras, sd_cas, sd_we} <= CMD_NOP; end
        state[s_idle_in_3_bit]: begin state <= s_idle_in_2;  {sd_cs, sd_ras, sd_cas, sd_we} <= CMD_NOP; end
        state[s_idle_in_2_bit]: begin state <= s_idle_in_1;  {sd_cs, sd_ras, sd_cas, sd_we} <= CMD_NOP; end
        state[s_idle_in_1_bit]: begin state <= s_idle;       {sd_cs, sd_ras, sd_cas, sd_we} <= CMD_NOP; end

        // Refresh cycle needs tRFC (63ns), so 6 idle cycles are needed @ 100MHz

        //-----------------------------------------------------
        //-- Dispatch all possible actions while idling (NOP)
        //-----------------------------------------------------

        state[s_idle_bit]: begin
          sd_ba                          <= addr[23:22];                 // Bank select, 2 bits
          sd_addr                        <= {addr[25:24], addr[21:11]} ; // RA0-RA12: 8192 Row address

          {sd_cs, sd_ras, sd_cas, sd_we} <= refresh_pending             ? CMD_AUTO_REFRESH :
                                            (|wmask_sticky) | rd_sticky ? CMD_ACTIVE :
                                                                          CMD_NOP;

          state                          <= refresh_pending             ? s_idle_in_2 : // *** Experimental result: Direct transition to s_idle does not work @ 40 MHz, s_idle_in_1 is unstable, sd_idle_in_2 is fine.
                                            (|wmask_sticky) | rd_sticky ? s_activate :
                                                                          s_idle;
        end

        // Busy flag is set while state machine is in the following states:

        //-----------------------------------------------------
        //-- Opening the row ready for reads or writes
        //-----------------------------------------------------

        state[s_activate_bit]: begin
          sd_data_drive                  <= ~rd_sticky;  // Drive or release bus early, before the SDRAM chip takes over to drive these lines
          {sd_cs, sd_ras, sd_cas, sd_we} <= CMD_NOP;
          state                          <= rd_sticky ? s_read_1 : s_write_1;
        end

        // RAS-to-CAS delay, also necessary for precharge, used in this state machine: 2 cycles.
        // Specification of AS4C32M16SB-7TCN: 21 ns --> Good for 1/(21e-9 / 2) = 95.23 MHz

        //-----------------------------------------------------
        //-- Processing the read transaction
        //-----------------------------------------------------

        state[s_read_1_bit]: begin
          sd_dqm                         <= 2'b00; // SDRAM chip shall drive the bus lines
          {sd_cs, sd_ras, sd_cas, sd_we} <= CMD_READ;
          sd_addr                        <= {3'b001, addr[10:2], 1'b0}; // Bit 10: Auto-precharge. CA0-CA9: 1024 Column address.
          state                          <= s_read_2;
        end

        state[s_read_2_bit]: begin
          {sd_cs, sd_ras, sd_cas, sd_we} <= CMD_NOP;
          state                          <= s_read_3;
        end

        state[s_read_3_bit]: state       <= s_read_4;


        state[s_read_4_bit]: begin
          dout[15:0]                     <= sd_data_in;
          state                          <= s_read_5;
        end

        // Busy is cleared when reaching this state, fulfilling the request:

        state[s_read_5_bit]: begin
          dout[31:16]                    <= sd_data_in;
          state                          <= s_idle;  // *** Experimental result: Direct transition to s_idle is fine @ 40 MHz
        end

        // Precharge (which is automatic here) needs 21 ns, therefore 2 idle cycles need to be inserted

        //-----------------------------------------------------
        // -- Processing the write transaction
        //-----------------------------------------------------

        state[s_write_1_bit]: begin
          sd_addr                        <= {3'b001, addr[10:2], 1'b0}; // Bit 10: Auto-precharge. CA0-CA9: 1024 Column address.
          sd_data_out                    <= din[15:0];
          sd_dqm                         <= ~wmask_sticky[1:0];
          {sd_cs, sd_ras, sd_cas, sd_we} <= CMD_WRITE;
          state                          <= s_write_2;
        end

        // Busy is cleared when reaching this state, fulfilling the request:

        state[s_write_2_bit]: begin
          sd_data_out                    <= din[31:16];
          sd_dqm                         <= ~wmask_sticky[3:2];
          {sd_cs, sd_ras, sd_cas, sd_we} <= CMD_NOP;
          state                          <= s_idle_in_2; // *** Experimental result: s_idle_in_1 does not work @ 40 MHz, s_idle_in_2 is fine.
        end

        // Write needs 14 ns internally, then Precharge needs 21 ns, therefore 3 idle cycles need to be inserted

      endcase
   end

endmodule
