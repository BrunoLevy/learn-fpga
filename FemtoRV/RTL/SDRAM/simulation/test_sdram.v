`timescale 1ns/100ps  // 1 ns time unit, 100 ps resolution
`default_nettype none // Makes it easier to detect typos !

module test_sdram;
    reg clk;
    always #12.5 clk = !clk;

    reg resetq = 0;

   /***************************************************************************/
   // SD-RAM-Controller
   /***************************************************************************/

   wire [31:0] sdram_rdata;
   wire sdram_busy;

   reg [3:0] sdram_wmask = 4'b0000;
   reg       sdram_rd    = 0;

   muchtoremember sdram(
    // Physical interface
    .sd_d(sdram_d),
    .sd_addr(sdram_a),
    .sd_dqm(sdram_dqm),
    .sd_cs(sdram_csn),
    .sd_ba(sdram_ba),
    .sd_we(sdram_wen),
    .sd_ras(sdram_rasn),
    .sd_cas(sdram_casn),
    .sd_clk(sdram_clk),
    .sd_cke(sdram_cke),

    // Internal bus interface
    .clk(clk),
    .resetn(resetq),
    .addr(mem_address[25:0]),
    .wmask(sdram_wmask),
    .rd(sdram_rd),
    .din(mem_wdata),
    .dout(sdram_rdata),
    .busy(sdram_busy)
  );

  wire [31:0] mem_address = 0;
  wire [31:0] mem_wdata = 32'h00030004;

   /***************************************************************************/
   // 64 MB SD-RAM
   /***************************************************************************/

  wire  sdram_csn;       // chip select
  wire  sdram_clk;       // clock to SDRAM
  wire  sdram_cke;       // clock enable to SDRAM
  wire  sdram_rasn;      // SDRAM RAS
  wire  sdram_casn;      // SDRAM CAS
  wire  sdram_wen;       // SDRAM write-enable
  wire [12:0] sdram_a;  // SDRAM address bus
  wire  [1:0] sdram_ba;  // SDRAM bank-address
  wire  [1:0] sdram_dqm; // byte select
  wire [15:0] sdram_d;

  mt48lc16m16a2 memory(
   .Dq(sdram_d),
   .Addr(sdram_a),
   .Ba(sdram_ba),
   .Clk(sdram_clk),
   .Cke(sdram_cke),
   .Cs_n(sdram_csn),
   .Ras_n(sdram_rasn),
   .Cas_n(sdram_casn),
   .We_n(sdram_wen),
   .Dqm(sdram_dqm)
   );

   /***************************************************************************/
   // Test sequence
   /***************************************************************************/

   integer i;
   initial begin
     $dumpfile("sdram.vcd");    // create a VCD waveform dump
     $dumpvars(0, test_sdram); // dump variable changes in the testbench
                              // and all modules under it

     clk = 0;
     resetq = 0;
     @(negedge clk);
     resetq = 1;

     for (i = 0; i < 11000; i = i + 1) begin
       @(negedge clk);
     end

     $monitor("t=%d: sdram_d = %8h Busy %b sdram_rdata %8h", $time, sdram_d, sdram_busy, sdram_rdata);

     $display(" --- Write access ---");
     sdram_wmask = 15;
     @(negedge clk);
     sdram_wmask = 0;

     for (i = 0; i < 64; i = i + 1) begin
       @(negedge clk);
     end

     $display(" --- Read access ---");
     sdram_rd = 1;
     @(negedge clk);
     sdram_rd = 0;

     for (i = 0; i < 64; i = i + 1) begin
       @(negedge clk);
     end

     $finish();
   end
endmodule
