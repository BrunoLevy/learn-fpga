#include "VfemtoRV32_bench.h"
#include "verilated.h"
#include <GLFW/glfw3.h>


// Emulates the 128x128 OLED display
class SSD1351 {
 public:
   SSD1351(
      CData& DIN, CData& CLK, CData& CS, CData& DC, CData& RST
   ) : DIN_(DIN), CLK_(CLK), CS_(CS), DC_(DC), RST_(RST) {
      cur_word_ = 0;
      cur_bit_ = 0;
      cur_command_ = 0;
      prev_CLK_ = 0;
      prev_CS_  = 1;
      x1_ = 0; x2_ = 127;
      y1_ = 0; y2_ = 127;
      start_line_ = 0;
      if(!glfwInit()) {
	 fprintf(stderr,"Could not initialize glfw\n");
	 exit(-1);
      }
      glfwWindowHint(GLFW_RESIZABLE,GL_FALSE);
      window_  = glfwCreateWindow(512,512,"FemtoRV32 SSD1351",nullptr,nullptr);
      glfwMakeContextCurrent(window_);
      glfwSwapInterval(1);
      glPixelZoom(4.0f,4.0f);
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
	    cur_arg_index_ = 0;
	 } else {

	   if(cur_arg_index_ < 2) {
	     cur_arg_[cur_arg_index_] = flip(cur_word_,8);
	     cur_arg_index_++;
	   }

	   // set x range
	   if(cur_command_ == 0x15 && cur_arg_index_ == 2) {
	     x1_ = cur_arg_[0]; x2_ = cur_arg_[1]; x_ = x1_;
	   }

	   // set y range
	   if(cur_command_ == 0x75 && cur_arg_index_ == 2) {
	     y1_ = cur_arg_[0]; y2_ = cur_arg_[1]; y_ = y1_;
	   }

	   // set display start line
	   if(cur_command_ == 0xa1 && cur_arg_index_ == 1) {
	     start_line_ = cur_arg_[0];
	     redraw();
	   }
	   
	   // draw pixels
	   if(cur_command_ == 0x5c) {
	     framebuffer_[(127-y_)*128+x_] = flip(cur_word_,16);
	     ++x_;
	     if(x_ > x2_) {
	       ++y_;
	       x_ = x1_;
	       if(x2_ > 63 || y_ > y2_) {
		 redraw();
	       }
	     }
	   } 
	 }
      }
   
      prev_CLK_ = CLK_;
      prev_CS_  = CS_;
   }

 private:

   void redraw() {
     glRasterPos2f(-1.0f,-1.0f);
     if(start_line_ != 0) {
       glDrawPixels(
	   128, start_line_, GL_RGB, GL_UNSIGNED_SHORT_5_6_5,
	   framebuffer_ + 128 * (128-start_line_) 
       );
     }
     glRasterPos2f(-1.0f,-1.0+2.0*float(start_line_)/127.0);
     glDrawPixels(
	128, 128-start_line_, GL_RGB, GL_UNSIGNED_SHORT_5_6_5,
	framebuffer_
     );
     glfwSwapBuffers(window_);
   }
  
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
};

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
