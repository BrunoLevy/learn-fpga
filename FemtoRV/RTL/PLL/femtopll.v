/*
 *  The PLL, that generates the internal clock (high freq) from the 
 * external one (lower freq).
 *  Trying to make something that is portable between different boards
 *  For now, ICEStick, ULX3S, ECP5 evaluation boards, FOMU supported.
 *  WIP: IceFeather
 */ 

`ifdef BENCH_OR_LINT
 `define PASSTHROUGH_PLL
`endif

/*
`ifdef TANGNANO9K
 `define PASSTHROUGH_PLL
`endif
*/

/**********************************************************************/

`ifdef PASSTHROUGH_PLL
module femtoPLL #(
 parameter freq = 60
) (
 input 	pclk,
 output clk	   
);
   assign clk = pclk;   
endmodule
`elsif GEARDOWN_PLL
module femtoPLL #(
 parameter freq = 25,   /*50 slight overclock is unstable*/
 parameter EXT_CLK_MHZ = 100
) (
 input	pclk,
 output clk	   
);

/*
#work around for no pll on olimex HX1K vq100 board
#right now assume this will only ever be used for this board
#so don't bother integrating EXT_CLK_MHZ into build system
#just fix to 100MHz
*/

   reg slow_clk;
   reg slowest_clk;

   always @(posedge pclk) begin
         slow_clk <= !slow_clk;
   end

   always @(posedge slow_clk) begin
         slowest_clk <= !slowest_clk;
   end

   assign clk = slowest_clk;   
endmodule
`else
 `ifdef ICE_STICK 
  `include "pll_icestick.v"
 `elsif ICE_ZERO 
  `include "pll_icezero.v" 
 `elsif ICE_BREAKER 
  `include "pll_icebreaker.v" 
 `elsif ICE_FEATHER
  `include "pll_icefeather.v"
 `elsif ICE_SUGAR
  `include "pll_icesugar.v"
 `elsif ULX3S
  `include "pll_ulx3s.v"
 `elsif ECP5_EVN
  `include "pll_ecp5_evn.v"
 `elsif FOMU
  `include "pll_fomu.v"
 `elsif ARTY
  `include "pll_arty.v"
 `elsif CMODA7
  `include "pll_cmod_a7.v"
 `elsif ICE40HX8K_EVB
  `include "pll_ice40hx8k_evb.v"
 `elsif TANGNANO9K
  `include "pll_tangnano9k.v"
 `endif
`endif

