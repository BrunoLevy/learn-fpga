#include "VfemtoRV32_bench.h"
#include "verilated.h"
#include <GLFW/glfw3.h>
#include "FPU_funcs.h"
#include "SSD1351.h"


int main(int argc, char** argv, char** env) {
   VfemtoRV32_bench top;
   SSD1351 oled(
      top.oled_DIN, top.oled_CLK, top.oled_CS, top.oled_DC, top.oled_RST
   );
   top.pclk = 0;
   for(;;) {
      top.pclk = !top.pclk;
      top.eval();
      oled.eval();
   }
   return 0;
}
