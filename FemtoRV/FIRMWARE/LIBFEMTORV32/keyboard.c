#include "femtorv32.h"
#include "keyboard.h"

int UART_pollkey() {
  uint64_t t0;
  int k1,k2;
  k1 = IO_IN(IO_UART_DAT);
  if(!(k1 & 256)) {   
    return 0;  // Bit 8 = 0: no data ready    
  }
  
  k1 &= 255;
  if(k1 != 27) {
    return k1;
  }

  // Two-character escape sequence
  t0 = milliseconds();
  while(milliseconds()-t0 < 10);
  while(milliseconds()-t0 < 100) {
    k2 = IO_IN(IO_UART_DAT);
    if(k2 & 256) {
      k2 &= 255;
      return (27 << 8) | k2;      
    }
  }

  // If no other character appears in
  // 100 ms, then it is just the escape key
  return 27;
}
