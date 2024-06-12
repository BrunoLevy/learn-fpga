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
`else
 `ifdef ICE_STICK 
  `include "pll_icestick.v"
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
 `elsif TANGNANO_9K
  `include "pll_tangnano9k.v"
 `endif
`endif

