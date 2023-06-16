#include "VSOC.h"
#include "verilated.h"
#include "femto_elf.h"
#include <iostream>


int main(int argc, char** argv, char** env) {
   VSOC top;
   top.CLK = 0;
   CData prev_LEDS;
   Elf32Info elf;
   int elf_status;
   // void* simulated_RAM = (void*)top.SOC__DOT__RAM__DOT__MEM;

   // Call eval() so that readmemh()/initial bocks are executed
   // before anything else.
   top.eval();

   // If ELF is specified on command line, load it into
   // simulated RAM. It will overwrite the RAM that was
   // previously initialized with readmemh().
   /*
   if(argc > 1) {
       elf_status = elf32_load_at(argv[1],&elf,simulated_RAM);
       if(elf_status != ELF32_OK) {
	   switch(elf_status) {
	   case ELF32_FILE_NOT_FOUND:
	       printf("\nNot found\n");
	       break;
	   case ELF32_HEADER_SIZE_MISMATCH:
	       printf("\nELF hdr mismatch\n");
	       break;
	   case ELF32_READ_ERROR:
	       printf("\nRead err\n");
	       break;
	   default:
	       printf("\nUnknown err\n");
	       break;
	   }
	   exit(-1);
       }
   }
   */

   // Main simulation loop.
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
