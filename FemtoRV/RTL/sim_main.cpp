#include "VfemtoRV32_bench.h"
  #include "verilated.h"
  int main(int argc, char** argv, char** env) {
      VfemtoRV32_bench* top = new VfemtoRV32_bench();
      top->pclk = 0;
      for(;;) {
	 top->pclk = !top->pclk;
	 top->eval(); 
      }
      delete top;
      return 0;
  }
