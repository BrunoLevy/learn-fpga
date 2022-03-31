#include "VSOC.h"
#include "verilated.h"
#include <iostream>

int main(int argc, char** argv, char** env) {
   VSOC top;
   top.CLK = 0;
   CData prev_LEDS;
   while(!Verilated::gotFinish()) {
      top.CLK = !top.CLK;
      top.eval();
      if(prev_LEDS != top.LEDS) {
	 std::cout << "LEDS: ";
	 for(int i=0; i<5; ++i) {
	    std::cout << ((top.LEDS >> (4-i)) & 1);
	 }
	 std::cout << std::endl;
      }
      prev_LEDS = top.LEDS;
   }
   return 0;
}
