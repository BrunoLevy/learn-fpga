#include "VfemtoRV32_bench.h"
#include "verilated.h"
#include "FPU_funcs.h"
#include "SSD1351.h"
#include <memory>
#include <fenv.h>
#include <xmmintrin.h>

int main(int argc, char** argv, char** env) {

   // simplest rounding = ignore LSBs
   fesetround(FE_TOWARDZERO);

   // for now, flush denormalized result to zero.   
   _MM_SET_FLUSH_ZERO_MODE(_MM_FLUSH_ZERO_ON); 
   
   VfemtoRV32_bench top;
   SSD1351 oled(
      top.oled_DIN, top.oled_CLK, top.oled_CS, top.oled_DC, top.oled_RST
   );
   top.pclk = 0;
   while(!Verilated::gotFinish()) {
      top.pclk = !top.pclk;
      top.eval();
      oled.eval();
   }
   return 0;
}
