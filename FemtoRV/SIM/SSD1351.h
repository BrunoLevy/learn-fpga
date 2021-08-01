/*****************************************************************/
#include "verilated.h"
#include <GLFW/glfw3.h>

// Emulates the 128x128 OLED display
class SSD1351 {
 public:
   SSD1351(
      CData& DIN, CData& CLK, CData& CS, CData& DC, CData& RST
   );

   void eval();

 private:
  void redraw();
  unsigned int flip(unsigned int x, unsigned int nb) {
      unsigned int result=0;
      for(unsigned int bit=0; bit<nb; ++bit) {
	 if(x & (1 << bit)) {
	    result |= (1 << (nb-1-bit));
	 }
      }
      return result;
   }
  
 private:
   CData& DIN_;
   CData& CLK_;
   CData& CS_;
   CData& DC_;
   CData& RST_;

   CData prev_CLK_;
   CData prev_CS_;
   unsigned int prev_word_;
   unsigned int cur_word_;
   unsigned int cur_bit_;
   unsigned int cur_command_;
   unsigned int cur_arg_[2];
   unsigned int cur_arg_index_;
   
   GLFWwindow* window_;

   unsigned short framebuffer_[128*128];
  
   unsigned int x_, x1_, x2_;
   unsigned int y_, y1_, y2_;
   unsigned int start_line_;

   bool fetch_next_half_;
};
