#!/bin/sh
# Automatically generates a PLL parameterized by output freq
# (instead of cryptic parameters)

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 FPGA_KIND INPUTFREQ" >&2
  exit 1
fi

FPGA_KIND=$1
INPUTFREQ=$2

echo "/* "
echo " * Do not edit this file, it was generated by gen_pll.sh"
echo " * "
echo " *   FPGA kind      : $1"
echo " *   Input frequency: $2 MHz"
echo " */"

case $FPGA_KIND in
   "ICE40")
      cat << EOF

 module femtoPLL #(
    parameter freq = 60
 ) (
    input wire pclk,
    output wire clk
 );
   generate
     case(freq)
EOF
      for OUTPUTFREQ in `cat frequencies.txt`
      do
        echo "     $OUTPUTFREQ: begin"
        icepll -i $INPUTFREQ -o $OUTPUTFREQ \
	    | egrep "DIVR|DIVF|DIVQ|FILTER_RANGE" \
	    | sed -e 's|[:()]||g' \
	    | awk '{printf("      parameter %s = %s;\n",$1,$3);}'
        echo "     end"
      done
      cat <<EOF
     endcase
   endgenerate

   SB_PLL40_CORE #(
      .FEEDBACK_PATH("SIMPLE"),
      .PLLOUT_SELECT("GENCLK"),
      .DIVR(4'b0000),
      .DIVF(7'b0000000), 
      .DIVQ(3'b000), 
      .FILTER_RANGE(3'b000),
   ) pll (
      .REFERENCECLK(pclk),
      .PLLOUTCORE(clk),
      .RESETB(1'b1),
      .BYPASS(1'b0)
   );
endmodule  
EOF
      ;;
   "ECP5")
      cat << EOF

 module femtoPLL #(
    parameter freq = 60
 ) (
    input wire pclk,
    output wire clk
 );
   generate
     case(freq)
EOF
      for OUTPUTFREQ in `cat frequencies.txt`
      do
          echo "     $OUTPUTFREQ: begin"
	  ecppll -i $INPUTFREQ -o $OUTPUTFREQ -f tmp.v > tmp.txt
          cat tmp.v \
	      | egrep "CLKI_DIV|CLKOP_DIV|CLKOP_CPHASE|CLKFB_DIV" \
	      | sed -e 's|[),.]| |g' -e 's|(|=|g' \
	      | awk '{printf("      parameter %s;\n",$1);}'
	  rm -f tmp.v tmp.txt
        echo "     end"
      done
      cat <<EOF
      endcase
   endgenerate
(* ICP_CURRENT="12" *) (* LPF_RESISTOR="8" *) (* MFG_ENABLE_FILTEROPAMP="1" *) (* MFG_GMCREF_SEL="2" *)
EHXPLLL #(
        .PLLRST_ENA("DISABLED"),
        .INTFB_WAKE("DISABLED"),
        .STDBY_ENABLE("DISABLED"),
        .DPHASE_SOURCE("DISABLED"),
        .OUTDIVIDER_MUXA("DIVA"),
        .OUTDIVIDER_MUXB("DIVB"),
        .OUTDIVIDER_MUXC("DIVC"),
        .OUTDIVIDER_MUXD("DIVD"),
        .CLKI_DIV(CLKI_DIV),
        .CLKOP_ENABLE("ENABLED"),
        .CLKOP_DIV(CLKOP_DIV),
        .CLKOP_CPHASE(CLKOP_CPHASE),
        .CLKOP_FPHASE(0),
        .FEEDBK_PATH("CLKOP"),
        .CLKFB_DIV(CLKFB_DIV)
    ) pll_i (
        .RST(1'b0),
        .STDBY(1'b0),
        .CLKI(pclk),
        .CLKOP(clk),
        .CLKFB(clk),
        .CLKINTFB(),
        .PHASESEL0(1'b0),
        .PHASESEL1(1'b0),
        .PHASEDIR(1'b1),
        .PHASESTEP(1'b1),
        .PHASELOADREG(1'b1),
        .PLLWAKESYNC(1'b0),
        .ENCLKOP(1'b0)
	);
endmodule  
EOF
      ;;
   *)
      echo FPGA_KIND needs to be one of ICE40,ECP5
      exit 1
      ;;
esac
