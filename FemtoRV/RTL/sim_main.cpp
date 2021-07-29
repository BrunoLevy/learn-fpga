#include "VfemtoRV32_bench.h"
#include "verilated.h"
#include <GLFW/glfw3.h>


// Emulates the 128x128 OLED display
class SSD1331 {
 public:
   SSD1331(
      CData& DIN, CData& CLK, CData& CS, CData& DC, CData& RST
   ) : DIN_(DIN), CLK_(CLK), CS_(CS), DC_(DC), RST_(RST) {
      cur_word_ = 0;
      cur_bit_ = 0;
      cur_command_ = 0;
      prev_CLK_ = 0;
      prev_CS_  = 1;
      if(!glfwInit()) {
	 fprintf(stderr,"Could not initialize glfw\n");
	 exit(-1);
      }
      glfwWindowHint(GLFW_RESIZABLE,GL_FALSE);
      window_  = glfwCreateWindow(128,128,"SSD1351",nullptr,nullptr);
      glfwMakeContextCurrent(window_);
      glfwSwapInterval(1);
      
   }

   void eval() {
      if(prev_CS_ && !CS_) {
	 cur_word_ = 0;
	 cur_bit_  = 0;
      }
   
      if(!CS_ && CLK_ && !prev_CLK_) {
	 cur_word_ |= ((unsigned int)(DIN_) << cur_bit_);
	 cur_bit_++;
      }

      if(!prev_CS_ && CS_) {
	 if(!DC_) {
	    cur_command_ = flip(cur_word_,8);
	    if(cur_command_ != 0x00) {
	       printf("\n0x%02x",cur_command_);
	    }
	    fb_index_ = 0;
	 } else {
	    if(cur_command_ == 0x5c) {
	       // printf(", 0x%04x",flip(cur_word_,16));
	       framebuffer_[fb_index_] = flip(cur_word_,16);
	       ++fb_index_;
	       if(!(fb_index_ % 128)) {
		 glDrawPixels(128, 128, GL_RGB, GL_UNSIGNED_SHORT_5_6_5, framebuffer_);
		 glfwSwapBuffers(window_);
	       }
	    } else {
	       printf(", 0x%02x",flip(cur_word_,8));
	    }
	 }
      }
   
      prev_CLK_ = CLK_;
      prev_CS_  = CS_;
   }
   
 private:
   CData& DIN_;
   CData& CLK_;
   CData& CS_;
   CData& DC_;
   CData& RST_;

   unsigned int flip(unsigned int x, unsigned int nb) {
      unsigned int result=0;
      for(unsigned int bit=0; bit<nb; ++bit) {
	 if(x & (1 << bit)) {
	    result |= (1 << (nb-1-bit));
	 }
      }
      return result;
   }

   CData prev_CLK_;
   CData prev_CS_;
   unsigned int cur_word_;
   unsigned int cur_bit_;
   unsigned int cur_command_;
   
   GLFWwindow* window_;

   unsigned short framebuffer_[128*128];
   unsigned int fb_index_;
};

int main(int argc, char** argv, char** env) {
   VfemtoRV32_bench top;
   SSD1331 oled(
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
