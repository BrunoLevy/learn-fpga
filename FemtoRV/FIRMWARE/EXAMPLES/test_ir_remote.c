/**
 * Displays data from IR remote using the built-in irda of the IceStick.
 * 
 * Disclaimer: very crappy code ahead !!!
 */ 

#include <femtorv32.h>
#include <femtoGL.h>

static inline int ir_status() {
   return !(IO_IN(IO_LEDS) & 16);
}

static inline int get_pulse_width() {
   int result = 0;
   while(!ir_status()) {
      ++result;
      if(result > 10000) {
	 return 10000;
      }
   }
   return result;
}


int frame[100];
int idx = 0;

static inline int decode() {
   int result = 0;
   int start = idx-16;
   if(start < 0) return -1;
   for(int b=0; b+start<idx; ++b) {
      if(frame[b+start] > 100) {
	 result |= (1 << b);
      }
   }
   return result;
}




void test_irda() RV32_FASTCODE;
void test_irda() {
   int nl = 0;
   for(;;) {
      int w = get_pulse_width();
      if(w >= 10000) {
	 if(nl == 0) {
	    int rcv = decode();
	    if(rcv != -1) {
	       printf("%x\n",rcv);
	    }
	    idx = 0;
	 }
	 nl = 1;
      } else {
	 delay(1);
	 frame[idx] = w;
	 idx++;
	 nl = 0;
      }
   }
}


int main() {
   femtosoc_tty_init();
   GL_set_font(&Font8x16);   
   test_irda();
}
